#include "web_session.h"

#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

#include <cstring>
#include <string>

namespace {
constexpr char kLanding[] = "https://link.zolmid.com/theme/ZolNit/app-login.html";
struct State {
  GtkWidget* window = nullptr;
  WebKitWebView* web = nullptr;
  FlMethodCall* pending = nullptr;
  GCancellable* cancellable = nullptr;
  guint timeout = 0;
  unsigned long generation = 0;
  std::string code;
  std::string destination;
};
State state;
FlMethodChannel* channel = nullptr;

void respond(bool success) {
  if (!state.pending) return;
  FlMethodCall* call = state.pending;
  state.pending = nullptr;
  g_autoptr(FlValue) result = fl_value_new_bool(success);
  fl_method_call_respond_success(call, result, nullptr);
  g_object_unref(call);
}

void close_session() {
  ++state.generation;
  state.code.clear();
  state.destination.clear();
  if (state.timeout) { g_source_remove(state.timeout); state.timeout = 0; }
  if (state.cancellable) {
    g_cancellable_cancel(state.cancellable);
    g_clear_object(&state.cancellable);
  }
  respond(false);
  GtkWidget* window = state.window;
  state.window = nullptr;
  state.web = nullptr;
  if (window) gtk_widget_destroy(window);
}

gboolean window_destroyed(GtkWidget*, GdkEvent*, gpointer) {
  close_session();
  return TRUE;
}

gboolean deny_permission(WebKitWebView*, WebKitPermissionRequest* request, gpointer) {
  webkit_permission_request_deny(request);
  return TRUE;
}

gboolean decide_policy(WebKitWebView*, WebKitPolicyDecision* decision,
                       WebKitPolicyDecisionType type, gpointer) {
  if (type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
    webkit_policy_decision_ignore(decision);
    return TRUE;
  }
  if (type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION) return FALSE;
  auto* action = webkit_navigation_policy_decision_get_navigation_action(
      WEBKIT_NAVIGATION_POLICY_DECISION(decision));
  auto* request = webkit_navigation_action_get_request(action);
  const gchar* uri = webkit_uri_request_get_uri(request);
  if (!uri || !g_str_has_prefix(uri, "https://link.zolmid.com/") ||
      (state.pending && !state.code.empty() && std::strcmp(uri, kLanding) != 0)) {
    webkit_policy_decision_ignore(decision);
    return TRUE;
  }
  return FALSE;
}

gboolean load_failed(WebKitWebView*, WebKitLoadEvent, const gchar*, GError*, gpointer) {
  if (state.pending) close_session();
  return FALSE;
}

struct Evaluation { unsigned long generation; };
void evaluated(GObject* object, GAsyncResult* result, gpointer data) {
  auto* eval = static_cast<Evaluation*>(data);
  const auto generation = eval->generation;
  delete eval;
  GError* error = nullptr;
#if WEBKIT_MAJOR_VERSION < 2 || (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
  auto* js_result = webkit_web_view_run_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);
  JSCValue* value = js_result ? webkit_javascript_result_get_js_value(js_result) : nullptr;
#else
  auto* js_result = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object), result, &error);
  JSCValue* value = js_result;
#endif
  const bool ok = !error && value && jsc_value_is_boolean(value) && jsc_value_to_boolean(value);
  if (js_result) {
#if WEBKIT_MAJOR_VERSION < 2 || (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
    webkit_javascript_result_unref(js_result);
#else
    g_object_unref(js_result);
#endif
  }
  g_clear_error(&error);
  if (generation != state.generation || object != G_OBJECT(state.web) || !state.pending) return;
  if (!ok) { close_session(); return; }
  if (state.timeout) { g_source_remove(state.timeout); state.timeout = 0; }
  respond(true);
}

void load_changed(WebKitWebView* web, WebKitLoadEvent event, gpointer) {
  if (event != WEBKIT_LOAD_FINISHED || !state.pending || web != state.web ||
      state.code.empty() || g_strcmp0(webkit_web_view_get_uri(web), kLanding) != 0) return;
  const std::string script = "(function(){if(window.top===window && window.location.href==='" +
      std::string(kLanding) + "' && window.ZolNitWebSession && typeof window.ZolNitWebSession.accept==='function'){window.ZolNitWebSession.accept('" +
      state.code + "','" + state.destination + "');return true}return false})()";
  state.code.clear();
  state.destination.clear();
  auto* eval = new Evaluation{state.generation};
#if WEBKIT_MAJOR_VERSION < 2 || (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION < 40)
  webkit_web_view_run_javascript(web, script.c_str(), state.cancellable, evaluated, eval);
#else
  webkit_web_view_evaluate_javascript(web, script.c_str(), -1, nullptr, nullptr,
                                     state.cancellable, evaluated, eval);
#endif
}

bool valid_code(const char* code) {
  if (!code || std::strlen(code) != 43) return false;
  for (const char* c = code; *c; ++c) {
    if (!g_ascii_isalnum(*c) && *c != '_' && *c != '-') return false;
  }
  return true;
}

void handle_call(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  if (std::strcmp(method, "close") == 0) {
    close_session();
    g_autoptr(FlValue) value = fl_value_new_bool(true);
    fl_method_call_respond_success(call, value, nullptr);
    return;
  }
  if (std::strcmp(method, "open") != 0) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(call, response, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(call);
  FlValue* code_value = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP ? fl_value_lookup_string(args, "code") : nullptr;
  FlValue* dest_value = args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP ? fl_value_lookup_string(args, "destination") : nullptr;
  const char* code = code_value && fl_value_get_type(code_value) == FL_VALUE_TYPE_STRING ? fl_value_get_string(code_value) : nullptr;
  const char* dest = dest_value && fl_value_get_type(dest_value) == FL_VALUE_TYPE_STRING ? fl_value_get_string(dest_value) : nullptr;
  if (!valid_code(code) || !dest || (std::strcmp(dest, "/") != 0 &&
      std::strcmp(dest, "/#/dashboard") != 0 && std::strcmp(dest, "/theme/ZolNit/downloads.html") != 0)) {
    g_autoptr(FlValue) value = fl_value_new_bool(false);
    fl_method_call_respond_success(call, value, nullptr);
    return;
  }
  close_session();
  state.pending = FL_METHOD_CALL(g_object_ref(call));
  state.code = code;
  state.destination = dest;
  state.cancellable = g_cancellable_new();
  WebKitWebContext* context = webkit_web_context_new_ephemeral();
  state.web = WEBKIT_WEB_VIEW(webkit_web_view_new_with_context(context));
  g_object_unref(context);
  WebKitSettings* settings = webkit_web_view_get_settings(state.web);
  webkit_settings_set_javascript_can_open_windows_automatically(settings, FALSE);
  state.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(state.window), "ZolNit");
  gtk_window_set_default_size(GTK_WINDOW(state.window), 900, 720);
  gtk_container_add(GTK_CONTAINER(state.window), GTK_WIDGET(state.web));
  g_signal_connect(state.window, "delete-event", G_CALLBACK(window_destroyed), nullptr);
  g_signal_connect(state.web, "permission-request", G_CALLBACK(deny_permission), nullptr);
  g_signal_connect(state.web, "decide-policy", G_CALLBACK(decide_policy), nullptr);
  g_signal_connect(state.web, "load-changed", G_CALLBACK(load_changed), nullptr);
  g_signal_connect(state.web, "load-failed", G_CALLBACK(load_failed), nullptr);
  state.timeout = g_timeout_add_seconds(15, [](gpointer) -> gboolean {
    state.timeout = 0;
    close_session();
    return G_SOURCE_REMOVE;
  }, nullptr);
  gtk_widget_show_all(state.window);
  webkit_web_view_load_uri(state.web, kLanding);
}
}  // namespace

void register_web_session(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel = fl_method_channel_new(messenger, "com.zolmid.zolnit/web_session", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, handle_call, nullptr, nullptr);
}

void close_web_session() {
  close_session();
  g_clear_object(&channel);
}
