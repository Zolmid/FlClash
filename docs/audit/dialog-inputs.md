# Dialog input follow-up

This batch adapts four remaining Patched interactions to the current widgets.

| Source | Current implementation |
| --- | --- |
| `dec59305d07c079c7895d6033d1f88cea94c14c5` | `NamedUrlDialog` has an explicit URL Paste action using the existing localization and glyph. Clipboard text is trimmed at its outer edges and truncated with Flutter's grapheme-aware field limit. It does not submit, split links, switch modes, or overwrite the name/AGE key. Empty text, platform failures, and completion after disposal leave the field unchanged. |
| `d6a032d8344bf65c5d1cdad217b7e6eb8bc4bcdf` | The WebDAV address field uses `TextInputType.url`; validation, credentials, redirects, and backup staging retain their existing owners. |
| `38d6e1c8bb10812de47f5c89d007423c630de503` | `CommonDialog` uses a stable local `PopScope` with the effective TV setting. System/toolbar `maybePop` first parks focus from its own `EditableText` or `Slider` on the existing focus scope. A second Back closes the dialog. Explicit submission/cancellation via `Navigator.pop(result)` still closes once with its result. The scope retains its focused-child history so `RemoteFocusAdapter` does not immediately refocus the input. No local-history entry or global back manager is added. |
| `e65a054b9f533f45554e3dfc6a25a57611ce0a36` | `InputDialog` accepts explicit autofocus independently of selecting all text. Creation of SSIDs and new script names opts in; existing edit/default focus and select-all behavior remain. Raw YAML creation opts in at its own call site. The existing NamedUrl URL autofocus and TV first-control behavior are retained. |

Focused regression coverage lives in `named_url_paste_test.dart`,
`input_autofocus_test.dart`, `dialog_input_focus_test.dart`, and the existing
profile-import, SSID, WebDAV, and raw-profile creation suites. The dialog tests
exercise TV input and Slider release, adapter-enabled focus parking, system and
toolbar Back, submit/IME/cancel results, non-TV behavior, and stacked dialogs.
Root coordinates Flutter analysis and tests for the shared workspace.

The existing URL validators and batch parser are unchanged. In particular,
`Uri.tryParse` can accept multiple whitespace-separated HTTP URLs as one URI;
this existing single-field validation issue is separate from the Paste action.
Batch mode remains explicit: HTTP URLs split by whitespace, while proxy share
links retain their whole line, including spaces in display names, and use one
share link per line. Credential-bearing URLs remain raw until the established
request authentication handling.
