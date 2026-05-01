#include "include/openidconnect_linux/openidconnect_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <libsecret/secret.h>

#define OPENIDCONNECT_SCHEMA openidconnect_get_schema()

const char kSecurityAccessError[] = "Security Access Error";
const char kMethodInitialize[] = "initialize";
const char kMethodRead[] = "read";
const char kMethodWrite[] = "write";
const char kMethodDelete[] = "delete";
const char kMethodContainsKey[] = "containsKey";
const char kNamePrefix[] = "io.concerti.openidconnect";

#define METHOD_PARAM_NAME(varName, args)                                             \
  g_autofree gchar* varName = g_strdup_printf(                                       \
      "%s.%s", kNamePrefix,                                                        \
      fl_value_get_string(fl_value_lookup_string(args, "key")))

#define OPENIDCONNECT_LINUX_PLUGIN(obj)                                          \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), openidconnect_linux_plugin_get_type(),      \
                              OpenidconnectLinuxPlugin))

struct _OpenidconnectLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(OpenidconnectLinuxPlugin, openidconnect_linux_plugin,
              g_object_get_type())

static FlMethodResponse* handle_error(const gchar* message, GError* error) {
  const gchar* domain = g_quark_to_string(error->domain);
  g_autofree gchar* error_message =
      g_strdup_printf("%s: %s (%d) (%s)", message, error->message, error->code,
                      domain);
  g_warning("%s", error_message);
  g_autoptr(FlValue) error_details = fl_value_new_map();
  fl_value_set_string_take(error_details, "domain", fl_value_new_string(domain));
  fl_value_set_string_take(error_details, "code", fl_value_new_int(error->code));
  fl_value_set_string_take(error_details, "message",
                           fl_value_new_string(error->message));
  return FL_METHOD_RESPONSE(fl_method_error_response_new(
      kSecurityAccessError, error_message, error_details));
}

const SecretSchema* openidconnect_get_schema(void) {
  static const SecretSchema the_schema = {
      "io.concerti.OpenIdConnectSecureStorage", SECRET_SCHEMA_NONE,
      {{"key", SECRET_SCHEMA_ATTRIBUTE_STRING}}};
  return &the_schema;
}

static void on_password_stored(GObject* source, GAsyncResult* result,
                               gpointer user_data) {
  GError* error = NULL;
  FlMethodCall* method_call = (FlMethodCall*)user_data;
  g_autoptr(FlMethodResponse) response = nullptr;

  secret_password_store_finish(result, &error);
  if (error != NULL) {
    response = handle_error("Failed to store secret", error);
    g_error_free(error);
  } else {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  fl_method_call_respond(method_call, response, nullptr);
  g_object_unref(method_call);
}

static void on_password_cleared(GObject* source, GAsyncResult* result,
                                gpointer user_data) {
  GError* error = NULL;
  FlMethodCall* method_call = (FlMethodCall*)user_data;
  g_autoptr(FlMethodResponse) response = nullptr;

  secret_password_clear_finish(result, &error);
  if (error != NULL) {
    response = handle_error("Failed to delete secret", error);
    g_error_free(error);
  } else {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  fl_method_call_respond(method_call, response, nullptr);
  g_object_unref(method_call);
}

static void on_password_lookup(GObject* source, GAsyncResult* result,
                               gpointer user_data) {
  GError* error = NULL;
  FlMethodCall* method_call = (FlMethodCall*)user_data;
  g_autoptr(FlMethodResponse) response = nullptr;

  gchar* password = secret_password_lookup_finish(result, &error);
  if (error != NULL) {
    response = handle_error("Failed to lookup secret", error);
    g_error_free(error);
  } else if (password == NULL) {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  } else {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(password)));
    secret_password_free(password);
  }

  fl_method_call_respond(method_call, response, nullptr);
  g_object_unref(method_call);
}

static void on_password_exists(GObject* source, GAsyncResult* result,
                               gpointer user_data) {
  GError* error = NULL;
  FlMethodCall* method_call = (FlMethodCall*)user_data;
  g_autoptr(FlMethodResponse) response = nullptr;

  gchar* password = secret_password_lookup_finish(result, &error);
  if (error != NULL) {
    response = handle_error("Failed to lookup secret", error);
    g_error_free(error);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_bool(password != NULL)));
    if (password != NULL) {
      secret_password_free(password);
    }
  }

  fl_method_call_respond(method_call, response, nullptr);
  g_object_unref(method_call);
}

static FlMethodResponse* handle_initialize() {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
}

static void openidconnect_linux_plugin_handle_method_call(
    OpenidconnectLinuxPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, kMethodInitialize) == 0) {
    response = handle_initialize();
  } else if (strcmp(method, kMethodWrite) == 0) {
    METHOD_PARAM_NAME(name, args);
    const gchar* content =
        fl_value_get_string(fl_value_lookup_string(args, "value"));
    g_object_ref(method_call);
    secret_password_store(OPENIDCONNECT_SCHEMA, SECRET_COLLECTION_DEFAULT, name,
                          content, NULL, on_password_stored, method_call, "key",
                          name, NULL);
    return;
  } else if (strcmp(method, kMethodRead) == 0) {
    METHOD_PARAM_NAME(name, args);
    g_object_ref(method_call);
    secret_password_lookup(OPENIDCONNECT_SCHEMA, NULL, on_password_lookup,
                           method_call, "key", name, NULL);
    return;
  } else if (strcmp(method, kMethodContainsKey) == 0) {
    METHOD_PARAM_NAME(name, args);
    g_object_ref(method_call);
    secret_password_lookup(OPENIDCONNECT_SCHEMA, NULL, on_password_exists,
                           method_call, "key", name, NULL);
    return;
  } else if (strcmp(method, kMethodDelete) == 0) {
    METHOD_PARAM_NAME(name, args);
    g_object_ref(method_call);
    secret_password_clear(OPENIDCONNECT_SCHEMA, NULL, on_password_cleared,
                          method_call, "key", name, NULL);
    return;
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void openidconnect_linux_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(openidconnect_linux_plugin_parent_class)->dispose(object);
}

static void openidconnect_linux_plugin_class_init(
    OpenidconnectLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = openidconnect_linux_plugin_dispose;
}

static void openidconnect_linux_plugin_init(OpenidconnectLinuxPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  OpenidconnectLinuxPlugin* plugin = OPENIDCONNECT_LINUX_PLUGIN(user_data);
  openidconnect_linux_plugin_handle_method_call(plugin, method_call);
}

void openidconnect_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  OpenidconnectLinuxPlugin* plugin = OPENIDCONNECT_LINUX_PLUGIN(
      g_object_new(openidconnect_linux_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "plugins.concerti.io/openidconnect_secure_storage",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
