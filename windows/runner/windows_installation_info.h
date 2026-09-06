#ifndef RUNNER_WINDOWS_INSTALLATION_INFO_H_
#define RUNNER_WINDOWS_INSTALLATION_INFO_H_

#include <string>

#include "windows_installation_policy.h"

namespace windows_installation {

struct InstallationInfo {
  Classification classification;
  std::wstring directory;
  std::wstring system_directory;
  std::wstring windows_directory;
};

// Read-only OS inspection. No installer activation, process launch, registry
// writes, or MSI configuration/repair calls are made by this function.
InstallationInfo ReadInstallationInfo();

}  // namespace windows_installation

#endif  // RUNNER_WINDOWS_INSTALLATION_INFO_H_
