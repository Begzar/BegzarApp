# Removes Firebase from Windows plugin registration.
# Firebase is not used on Windows in this app; linking it only produces noise.

set(_GENERATED_PLUGINS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake")
set(_GENERATED_REGISTRANT "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc")
set(_FILTERED_PLUGINS "${CMAKE_BINARY_DIR}/generated_plugins_no_firebase.cmake")

if(EXISTS "${_GENERATED_PLUGINS}")
  file(READ "${_GENERATED_PLUGINS}" _plugins_content)
  string(REGEX REPLACE "[ \t]*firebase_core\r?\n" "\n" _plugins_content "${_plugins_content}")
  file(WRITE "${_FILTERED_PLUGINS}" "${_plugins_content}")
  include("${_FILTERED_PLUGINS}")
else()
  include("${_GENERATED_PLUGINS}")
endif()

if(EXISTS "${_GENERATED_REGISTRANT}")
  file(READ "${_GENERATED_REGISTRANT}" _registrant_content)
  string(REGEX REPLACE "#include <firebase_core/firebase_core_plugin_c_api.h>\r?\n" "" _registrant_content "${_registrant_content}")
  string(REGEX REPLACE "  FirebaseCorePluginCApiRegisterWithRegistrar\\(\r?\n      registry->GetRegistrarForPlugin\\(\"FirebaseCorePluginCApi\"\\)\\);\r?\n" "" _registrant_content "${_registrant_content}")
  file(WRITE "${_GENERATED_REGISTRANT}" "${_registrant_content}")
endif()
