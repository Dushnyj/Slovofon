#include "windows_installation_info.h"

#include <windows.h>
#include <msi.h>

#include <optional>
#include <string>
#include <vector>

namespace windows_installation {
namespace {

constexpr DWORD kPathCapacity = 32768;
// These identities must stay in sync with the production Inno/WiX installers.
// Preview installers deliberately use separate identities and are not matched.
constexpr wchar_t kInnoUninstallKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\"
    L"{C8CE9579-9F96-40B5-A58C-9726E9F76F89}_is1";
constexpr wchar_t kMsiMarkerKey[] = L"Software\\Slovofon\\Installer";
constexpr wchar_t kMsiUpgradeCode[] =
    L"{9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C}";
// New-WixInstallerSource.ps1: New-StableGuid -Value 'Slovofon.exe'.
constexpr wchar_t kMsiExecutableComponent[] =
    L"{B04B35C6-BE49-C53E-95C5-5B281775CF4A}";

class ReadHandle {
 public:
  explicit ReadHandle(const std::wstring& path)
      : value_(CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES,
                           FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS,
                           nullptr)) {}
  ~ReadHandle() {
    if (value_ != INVALID_HANDLE_VALUE) CloseHandle(value_);
  }
  ReadHandle(const ReadHandle&) = delete;
  ReadHandle& operator=(const ReadHandle&) = delete;
  HANDLE get() const { return value_; }

 private:
  HANDLE value_;
};

std::optional<std::wstring> FinalLocalPath(HANDLE handle) {
  std::vector<wchar_t> buffer(kPathCapacity);
  const auto length = GetFinalPathNameByHandleW(
      handle, buffer.data(), kPathCapacity, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
  if (length == 0 || length >= kPathCapacity) return std::nullopt;
  return NormalizeLocalDirectory(std::wstring(buffer.data(), length));
}

struct DirectoryIdentity {
  std::wstring path;
  BY_HANDLE_FILE_INFORMATION information;
};

std::optional<DirectoryIdentity> OpenDirectory(const std::wstring& raw_path) {
  const auto path = NormalizeLocalDirectory(raw_path);
  if (!path) return std::nullopt;
  if (GetDriveTypeW(path->substr(0, 3).c_str()) == DRIVE_REMOTE) {
    return std::nullopt;
  }
  // The prefix prevents long absolute paths from being truncated by Win32.
  ReadHandle handle(L"\\\\?\\" + *path);
  if (handle.get() == INVALID_HANDLE_VALUE) return std::nullopt;
  BY_HANDLE_FILE_INFORMATION information{};
  if (!GetFileInformationByHandle(handle.get(), &information) ||
      (information.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0 ||
      (information.nFileIndexHigh == 0 && information.nFileIndexLow == 0)) {
    return std::nullopt;
  }
  const auto final_path = FinalLocalPath(handle.get());
  if (!final_path) return std::nullopt;
  return DirectoryIdentity{*final_path, information};
}

std::optional<DirectoryIdentity> DirectoryForExecutable(
    const std::wstring& raw_path) {
  const auto path = NormalizeLocalDirectory(raw_path);
  if (!path) return std::nullopt;
  if (GetDriveTypeW(path->substr(0, 3).c_str()) == DRIVE_REMOTE) {
    return std::nullopt;
  }
  ReadHandle executable(L"\\\\?\\" + *path);
  if (executable.get() == INVALID_HANDLE_VALUE) return std::nullopt;
  const auto final_path = FinalLocalPath(executable.get());
  if (!final_path) return std::nullopt;
  const auto separator = final_path->find_last_of(L'\\');
  if (separator == std::wstring::npos ||
      CompareStringOrdinal(final_path->c_str() + separator + 1, -1,
                           L"Slovofon.exe", -1, TRUE) != CSTR_EQUAL) {
    return std::nullopt;
  }
  return OpenDirectory(final_path->substr(0, separator));
}

DirectoryRelation CompareIdentity(
    const DirectoryIdentity& executable,
    const std::optional<DirectoryIdentity>& registered) {
  if (!registered) return DirectoryRelation::kUnresolved;
  // File identity handles case, short paths and junction aliases without
  // equating distinct case-sensitive directories or merely shared prefixes.
  const auto& a = executable.information;
  const auto& b = registered->information;
  return a.dwVolumeSerialNumber == b.dwVolumeSerialNumber &&
                 a.nFileIndexHigh == b.nFileIndexHigh &&
                 a.nFileIndexLow == b.nFileIndexLow &&
                 CompareStringOrdinal(executable.path.c_str(), -1,
                                      registered->path.c_str(), -1, TRUE) ==
                     CSTR_EQUAL
             ? DirectoryRelation::kSame
             : DirectoryRelation::kDifferent;
}

DirectoryRelation CompareDirectory(const DirectoryIdentity& executable,
                                   const std::wstring& install_location) {
  return CompareIdentity(executable, OpenDirectory(install_location));
}

std::optional<std::wstring> ReadRegistryString(HKEY key, const wchar_t* name) {
  DWORD type = 0;
  DWORD byte_count = 0;
  if (RegQueryValueExW(key, name, nullptr, &type, nullptr, &byte_count) !=
          ERROR_SUCCESS ||
      (type != REG_SZ && type != REG_EXPAND_SZ) || byte_count == 0 ||
      byte_count > kPathCapacity * sizeof(wchar_t) ||
      byte_count % sizeof(wchar_t) != 0) {
    return std::nullopt;
  }
  std::vector<wchar_t> buffer(byte_count / sizeof(wchar_t), L'\0');
  const DWORD original_type = type;
  if (RegQueryValueExW(key, name, nullptr, &type,
                       reinterpret_cast<BYTE*>(buffer.data()), &byte_count) !=
          ERROR_SUCCESS ||
      type != original_type || byte_count == 0 ||
      byte_count % sizeof(wchar_t) != 0) {
    return std::nullopt;
  }
  const auto character_count = byte_count / sizeof(wchar_t);
  if (character_count > buffer.size() || buffer[character_count - 1] != L'\0') {
    return std::nullopt;
  }
  std::wstring value(buffer.data(), character_count - 1);
  if (value.empty() || value.find(L'\0') != std::wstring::npos) {
    return std::nullopt;
  }
  if (type == REG_EXPAND_SZ) {
    std::vector<wchar_t> expanded(kPathCapacity);
    const auto length =
        ExpandEnvironmentStringsW(value.c_str(), expanded.data(), kPathCapacity);
    if (length == 0 || length > kPathCapacity) return std::nullopt;
    value.assign(expanded.data(), length - 1);
  }
  return value;
}

void ReadRegistration(HKEY root, REGSAM view, const wchar_t* key_path, Kind kind,
                      Scope scope, const DirectoryIdentity& executable,
                      std::vector<Evidence>* evidence) {
  HKEY key = nullptr;
  const auto status =
      RegOpenKeyExW(root, key_path, 0, KEY_QUERY_VALUE | view, &key);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) return;
  DirectoryRelation relation = DirectoryRelation::kUnresolved;
  if (status == ERROR_SUCCESS) {
    const auto type = kind == Kind::kMsi ? ReadRegistryString(key, L"Type")
                                       : std::optional<std::wstring>(L"setup");
    const auto location = ReadRegistryString(key, L"InstallLocation");
    if (location && type &&
        (kind != Kind::kMsi || *type == L"msi")) {
      relation = CompareDirectory(executable, *location);
    }
    RegCloseKey(key);
  }
  evidence->push_back({kind, scope, relation});
}

void ReadLegacyMsi(const DirectoryIdentity& executable,
                   std::vector<Evidence>* evidence) {
  // Status queries only; unlike Win32_Product / configuration APIs, these do
  // not trigger repair. Enumeration stays on this calling thread.
  for (DWORD index = 0; index < 256; ++index) {
    wchar_t product_code[39]{};
    const auto status =
        MsiEnumRelatedProductsW(kMsiUpgradeCode, 0, index, product_code);
    if (status == ERROR_NO_MORE_ITEMS) return;
    if (status != ERROR_SUCCESS) break;
    std::vector<wchar_t> location(kPathCapacity);
    DWORD length = kPathCapacity;
    const auto query = MsiGetProductInfoW(product_code, L"InstallLocation",
                                         location.data(), &length);
    auto relation = DirectoryRelation::kUnresolved;
    if (query == ERROR_SUCCESS && length > 0 && length < kPathCapacity) {
      relation = CompareDirectory(executable,
                                  std::wstring(location.data(), length));
    } else if (query == ERROR_UNKNOWN_PROPERTY ||
               (query == ERROR_SUCCESS && length == 0)) {
      // Pre-marker packages already had a stable EXE component. Resolve it
      // within this verified related product, never by display name/default
      // folder or global component presence. This is a read-only status API.
      length = kPathCapacity;
      const auto state = MsiGetComponentPathW(product_code,
          kMsiExecutableComponent, location.data(), &length);
      if (state == INSTALLSTATE_LOCAL && length > 0 && length < kPathCapacity) {
        relation = CompareIdentity(executable, DirectoryForExecutable(
            std::wstring(location.data(), length)));
      }
    }
    evidence->push_back({Kind::kMsi, Scope::kNone, relation});
  }
  evidence->push_back({Kind::kMsi, Scope::kNone,
                       DirectoryRelation::kUnresolved});
}

std::wstring SystemDirectory(bool windows_directory) {
  std::vector<wchar_t> buffer(kPathCapacity);
  const auto length = windows_directory
                          ? GetWindowsDirectoryW(buffer.data(), kPathCapacity)
                          : GetSystemDirectoryW(buffer.data(), kPathCapacity);
  if (length == 0 || length >= kPathCapacity) return {};
  const auto directory = OpenDirectory(std::wstring(buffer.data(), length));
  return directory ? directory->path : std::wstring();
}

}  // namespace

InstallationInfo ReadInstallationInfo() {
  InstallationInfo info;
  info.system_directory = SystemDirectory(false);
  info.windows_directory = SystemDirectory(true);
  std::vector<wchar_t> module_path(kPathCapacity);
  const auto length =
      GetModuleFileNameW(nullptr, module_path.data(), kPathCapacity);
  if (length == 0 || length >= kPathCapacity) return info;
  const auto executable =
      DirectoryForExecutable(std::wstring(module_path.data(), length));
  if (!executable) return info;
  info.directory = executable->path;
  std::vector<Evidence> evidence;
  for (const auto view : {KEY_WOW64_64KEY, KEY_WOW64_32KEY}) {
    ReadRegistration(HKEY_CURRENT_USER, view, kInnoUninstallKey, Kind::kSetup,
                     Scope::kUser, *executable, &evidence);
    ReadRegistration(HKEY_LOCAL_MACHINE, view, kInnoUninstallKey, Kind::kSetup,
                     Scope::kMachine, *executable, &evidence);
    ReadRegistration(HKEY_LOCAL_MACHINE, view, kMsiMarkerKey, Kind::kMsi,
                     Scope::kNone, *executable, &evidence);
  }
  ReadLegacyMsi(*executable, &evidence);
  info.classification = Classify(true, evidence);
  return info;
}

}  // namespace windows_installation
