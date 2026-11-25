#ifndef RUNNER_RUNNING_PROGRAMS_PLUGIN_H_
#define RUNNER_RUNNING_PROGRAMS_PLUGIN_H_

#include <flutter/binary_messenger.h>

// Registers the method channel "cloud.begzar.begzar/running_programs", which
// answers "list" with the full path of the executable behind each running
// process, as UTF-8 strings.
void RegisterRunningProgramsPlugin(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_RUNNING_PROGRAMS_PLUGIN_H_
