# Invoked as a PRE_BUILD step so regenerations of the registrant stay Firebase-free.
if(NOT DEFINED REGISTRANT_PATH)
  message(FATAL_ERROR "REGISTRANT_PATH must be set")
endif()

if(EXISTS "${REGISTRANT_PATH}")
  file(READ "${REGISTRANT_PATH}" _registrant_content)
  string(REGEX REPLACE "#include <firebase_core/firebase_core_plugin_c_api.h>\r?\n" "" _registrant_content "${_registrant_content}")
  string(REGEX REPLACE "  FirebaseCorePluginCApiRegisterWithRegistrar\\(\r?\n      registry->GetRegistrarForPlugin\\(\"FirebaseCorePluginCApi\"\\)\\);\r?\n" "" _registrant_content "${_registrant_content}")
  file(WRITE "${REGISTRANT_PATH}" "${_registrant_content}")
endif()
