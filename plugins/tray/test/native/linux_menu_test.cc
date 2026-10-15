#include "../../linux/tray_plugin.cc"
#include <iostream>
#include <libdbusmenu-gtk/parser.h>
#include <stdexcept>
#include <string>

static void check(bool condition, const char *message) {
  if (!condition)
    throw std::runtime_error(message);
}

struct TestMessenger {
  GObject parent_instance;
  gpointer handler_data;
  GDestroyNotify handler_destroy;
  guint selection_count;
  gint selected_id;
  bool valid_message;
  bool received_activation_token;
};

struct TestMessengerClass {
  GObjectClass parent_class;
};

static void test_messenger_interface_init(FlBinaryMessengerInterface *iface);

G_DEFINE_TYPE_WITH_CODE(
    TestMessenger, test_messenger, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(fl_binary_messenger_get_type(),
                          test_messenger_interface_init))

static void set_message_handler(FlBinaryMessenger *messenger, const gchar *,
                                FlBinaryMessengerMessageHandler,
                                gpointer user_data,
                                GDestroyNotify destroy_notify) {
  auto *self = reinterpret_cast<TestMessenger *>(messenger);
  if (self->handler_destroy != nullptr)
    self->handler_destroy(self->handler_data);
  self->handler_data = user_data;
  self->handler_destroy = destroy_notify;
}

static void send_on_channel(FlBinaryMessenger *messenger, const gchar *channel,
                             GBytes *message, GCancellable *cancellable,
                             GAsyncReadyCallback callback, gpointer user_data) {
  auto *self = reinterpret_cast<TestMessenger *>(messenger);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  auto *codec_class = FL_METHOD_CODEC_GET_CLASS(codec);
  g_autofree gchar *method = nullptr;
  g_autoptr(FlValue) args = nullptr;
  g_autoptr(GError) error = nullptr;
  bool decoded = codec_class->decode_method_call(
      FL_METHOD_CODEC(codec), message, &method, &args, &error);
  self->valid_message = decoded && g_strcmp0(channel, "tray") == 0 &&
                        g_strcmp0(method, "onMenuItemSelected") == 0;
  if (self->valid_message) {
    ++self->selection_count;
    self->selected_id =
        fl_value_get_int(fl_value_lookup_string(args, "id"));
    self->received_activation_token =
        g_strcmp0(string_value(args, "activationToken"), "test-token") == 0;
  }
  g_autoptr(GTask) task = g_task_new(messenger, cancellable, callback, user_data);
  g_task_return_pointer(
      task, codec_class->encode_success_envelope(FL_METHOD_CODEC(codec), nullptr,
                                                 nullptr),
      reinterpret_cast<GDestroyNotify>(g_bytes_unref));
}

static GBytes *send_on_channel_finish(FlBinaryMessenger *, GAsyncResult *result,
                                      GError **error) {
  return static_cast<GBytes *>(g_task_propagate_pointer(G_TASK(result), error));
}

static void test_messenger_interface_init(FlBinaryMessengerInterface *iface) {
  iface->set_message_handler_on_channel = set_message_handler;
  iface->send_on_channel = send_on_channel;
  iface->send_on_channel_finish = send_on_channel_finish;
}

static void test_messenger_class_init(TestMessengerClass *) {}

static void test_messenger_init(TestMessenger *self) {
  self->valid_message = true;
}

static void observe_activation(GtkMenuItem *, gpointer data) {
  ++*static_cast<guint *>(data);
}

static FlValue *node(int id) {
  FlValue *entry = fl_value_new_map();
  fl_value_set_string_take(entry, "type", fl_value_new_string("checkbox"));
  fl_value_set_string_take(entry, "id", fl_value_new_int(id));
  fl_value_set_string_take(
      entry, "key",
      fl_value_new_string(("node-" + std::to_string(id)).c_str()));
  fl_value_set_string_take(entry, "label", fl_value_new_string("香港 & A"));
  fl_value_set_string_take(entry, "sublabel", fl_value_new_string("42 ms"));
  fl_value_set_string_take(entry, "checked", fl_value_new_bool(false));
  return entry;
}

static FlValue *group(const char *name, FlValue *items) {
  FlValue *entry = fl_value_new_map();
  fl_value_set_string_take(entry, "type", fl_value_new_string("submenu"));
  fl_value_set_string_take(entry, "label", fl_value_new_string(name));
  fl_value_set_string_take(entry, "items", items);
  return entry;
}

static GtkWidget *child_at(GtkWidget *menu, guint position) {
  GList *children = gtk_container_get_children(GTK_CONTAINER(menu));
  GtkWidget *child = GTK_WIDGET(g_list_nth_data(children, position));
  g_list_free(children);
  return child;
}

static guint child_count(GtkWidget *menu) {
  GList *children = gtk_container_get_children(GTK_CONTAINER(menu));
  guint length = g_list_length(children);
  g_list_free(children);
  return length;
}

static void drain_events() {
  while (g_main_context_iteration(nullptr, FALSE)) {
  }
}

int main(int argc, char **argv) {
  gtk_init(&argc, &argv);
  try {
    g_autoptr(FlValue) items = fl_value_new_list();
    FlValue *nodes = fl_value_new_list();
    for (int i = 0; i < 2000; ++i)
      fl_value_append_take(nodes, node(1024 + i));
    fl_value_append_take(items, group("Proxy", nodes));
    FlValue *nested = fl_value_new_list();
    fl_value_append_take(nested, node(5000));
    FlValue *other = fl_value_new_list();
    fl_value_append_take(other, group("Nested", nested));
    fl_value_append_take(items, group("Other", other));
    GtkWidget *menu = build_menu(items);
    g_object_ref_sink(menu);
    g_clear_pointer(&items, fl_value_unref);
    gtk_widget_show_all(menu);
    DbusmenuMenuitem *exported = dbusmenu_gtk_parse_menu_structure(menu);
    drain_events();

    TrayPlugin plugin{};
    plugin.menu = menu;
    auto *messenger = reinterpret_cast<TestMessenger *>(
        g_object_new(test_messenger_get_type(), nullptr));
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    plugin.channel = fl_method_channel_new(FL_BINARY_MESSENGER(messenger), "tray",
                                           FL_METHOD_CODEC(codec));
    plugin.pending_activation_token = g_strdup("test-token");
    active_plugin = &plugin;
    GtkWidget *first_item = child_at(menu, 0);
    GtkWidget *first = gtk_menu_item_get_submenu(GTK_MENU_ITEM(first_item));
    GtkWidget *other_item = child_at(menu, 1);
    GtkWidget *other_menu =
        gtk_menu_item_get_submenu(GTK_MENU_ITEM(other_item));
    check(child_count(menu) == 2, "root menu missing groups");
    check(child_count(first) == 2000 && child_count(other_menu) == 1,
          "initial menu is missing submenu rows");
    GtkWidget *selected = find_menu_item(menu, "node-1024");
    check(selected != nullptr, "unopened node has no native widget");
    guint observed_activations = 0;
    g_signal_connect(selected, "activate", G_CALLBACK(observe_activation),
                     &observed_activations);
    GtkWidget *nested_item = child_at(other_menu, 0);
    GtkWidget *nested_menu =
        gtk_menu_item_get_submenu(GTK_MENU_ITEM(nested_item));
    check(child_count(nested_menu) == 1 &&
              find_menu_item(menu, "node-5000") != nullptr,
          "initial menu is missing nested submenu rows");
    auto *first_exported = dbusmenu_gtk_parse_get_cached_item(first_item);
    check(g_strcmp0(dbusmenu_menuitem_property_get(
                        first_exported, DBUSMENU_MENUITEM_PROP_CHILD_DISPLAY),
                    "submenu") == 0,
          "group is not exported as a submenu");
    check(g_list_length(dbusmenu_menuitem_get_children(first_exported)) == 2000,
          "initial export is missing submenu rows");
    auto *nested_exported = dbusmenu_gtk_parse_get_cached_item(nested_item);
    check(g_list_length(dbusmenu_menuitem_get_children(nested_exported)) == 1,
          "initial export is missing nested submenu rows");

    g_autoptr(FlValue) update = fl_value_new_map();
    fl_value_set_string_take(update, "key", fl_value_new_string("node-1024"));
    fl_value_set_string_take(update, "sublabel",
                             fl_value_new_string("Timeout"));
    fl_value_set_string_take(update, "checked", fl_value_new_bool(true));
    check(apply_menu_item_update(&plugin, update), "unopened update rejected");

    g_autoptr(FlValue) bad_batch = fl_value_new_map();
    FlValue *updates = fl_value_new_list();
    FlValue *changed = fl_value_new_map();
    fl_value_set_string_take(changed, "key", fl_value_new_string("node-1024"));
    fl_value_set_string_take(changed, "label", fl_value_new_string("wrong"));
    fl_value_append_take(updates, changed);
    FlValue *missing = fl_value_new_map();
    fl_value_set_string_take(missing, "key", fl_value_new_string("missing"));
    fl_value_append_take(updates, missing);
    fl_value_set_string_take(bad_batch, "updates", updates);
    g_autoptr(FlMethodResponse) response =
        handle_update_menu_items(&plugin, bad_batch);
    check(!fl_value_get_bool(fl_method_success_response_get_result(
              FL_METHOD_SUCCESS_RESPONSE(response))),
          "invalid batch was accepted");

    check(g_strcmp0(gtk_menu_item_get_label(GTK_MENU_ITEM(selected)),
                    "香港 & A  (Timeout)") == 0,
          "unopened update lost or invalid batch partially applied");
    check(gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(selected)),
          "unopened checkmark update lost");
    check(messenger->selection_count == 0 && observed_activations == 1,
          "programmatic check invoked selection or blocked another observer");
    check(plugin.pending_activation_token != nullptr,
          "programmatic check consumed the activation token");
    GtkWidget *next_selected = find_menu_item(menu, "node-1025");
    g_autoptr(FlValue) selection_update = fl_value_new_map();
    FlValue *selection_updates = fl_value_new_list();
    FlValue *uncheck = fl_value_new_map();
    fl_value_set_string_take(uncheck, "key", fl_value_new_string("node-1024"));
    fl_value_set_string_take(uncheck, "checked", fl_value_new_bool(false));
    fl_value_append_take(selection_updates, uncheck);
    FlValue *check_next = fl_value_new_map();
    fl_value_set_string_take(check_next, "key", fl_value_new_string("node-1025"));
    fl_value_set_string_take(check_next, "checked", fl_value_new_bool(true));
    fl_value_append_take(selection_updates, check_next);
    fl_value_set_string_take(selection_update, "updates", selection_updates);
    g_autoptr(FlMethodResponse) selection_response =
        handle_update_menu_items(&plugin, selection_update);
    check(fl_value_get_bool(fl_method_success_response_get_result(
              FL_METHOD_SUCCESS_RESPONSE(selection_response))),
          "selection patch batch was rejected");
    drain_events();
    check(!gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(selected)) &&
              gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(next_selected)),
          "selection did not move from A to B");
    check(messenger->selection_count == 0 && observed_activations == 2,
          "A to B patch dispatched a user selection");
    auto *selected_exported = dbusmenu_gtk_parse_get_cached_item(selected);
    auto *next_exported = dbusmenu_gtk_parse_get_cached_item(next_selected);
    check(dbusmenu_menuitem_property_get_int(
              selected_exported, DBUSMENU_MENUITEM_PROP_TOGGLE_STATE) ==
              DBUSMENU_MENUITEM_TOGGLE_STATE_UNCHECKED &&
              dbusmenu_menuitem_property_get_int(
                  next_exported, DBUSMENU_MENUITEM_PROP_TOGGLE_STATE) ==
                  DBUSMENU_MENUITEM_TOGGLE_STATE_CHECKED,
          "selection patch did not reach the DBus menu");
    gtk_menu_item_activate(GTK_MENU_ITEM(selected));
    drain_events();
    check(messenger->valid_message && messenger->selection_count == 1 &&
              messenger->selected_id == 1024 &&
              messenger->received_activation_token &&
              plugin.pending_activation_token == nullptr,
          "one user activation did not dispatch exactly one selection");
    dbusmenu_menuitem_send_about_to_show(first_exported, nullptr, nullptr);
    drain_events();
    check(child_count(first) == 2000 &&
              find_menu_item(menu, "node-1024") == selected,
          "opening rebuilt submenu rows");
    check(dbusmenu_gtk_parse_get_cached_item(first_item) == first_exported &&
              g_list_length(dbusmenu_menuitem_get_children(first_exported)) ==
                  2000,
          "opening changed the exported submenu");
    fl_value_set_string_take(update, "sublabel", fl_value_new_string("17 ms"));
    check(apply_menu_item_update(&plugin, update), "visible update rejected");
    check(g_strcmp0(gtk_menu_item_get_label(GTK_MENU_ITEM(selected)),
                    "香港 & A  (17 ms)") == 0,
          "visible update lost");

    fl_value_set_string_take(update, "key", fl_value_new_string("node-5000"));
    check(apply_menu_item_update(&plugin, update), "nested update rejected");
    check(g_strcmp0(
              gtk_menu_item_get_label(GTK_MENU_ITEM(child_at(nested_menu, 0))),
              "香港 & A  (17 ms)") == 0,
          "nested update lost");
    check(messenger->selection_count == 1,
          "later programmatic updates dispatched another user selection");
    gtk_widget_destroy(menu);
    g_object_unref(menu);
    g_object_unref(exported);
    drain_events();
    plugin.menu = build_menu(nullptr);
    g_object_ref_sink(plugin.menu);
    check(!apply_menu_item_update(&plugin, update),
          "stale key survived rebuild");
    release_tray(&plugin);
    active_plugin = nullptr;
    g_clear_object(&plugin.channel);
    fl_binary_messenger_set_message_handler_on_channel(
        FL_BINARY_MESSENGER(messenger), "tray", nullptr, nullptr, nullptr);
    g_object_unref(messenger);
    std::cout << "Native Linux menu tests passed\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
