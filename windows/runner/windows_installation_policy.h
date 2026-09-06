#ifndef RUNNER_WINDOWS_INSTALLATION_POLICY_H_
#define RUNNER_WINDOWS_INSTALLATION_POLICY_H_

#include <optional>
#include <string>
#include <vector>

namespace windows_installation {

enum class Kind { kUnknown, kPortable, kSetup, kMsi };
enum class Scope { kNone, kUser, kMachine };
enum class DirectoryRelation { kDifferent, kSame, kUnresolved };

struct Evidence {
  Kind kind;
  Scope scope;
  DirectoryRelation directory_relation;
};

struct Classification {
  Kind kind = Kind::kUnknown;
  Scope scope = Scope::kNone;
};

// Accept only unambiguous, absolute local DOS paths. Device/UNC paths and drive
// roots cannot be auto-update destinations. Normalization is lexical only;
// callers must open the directory and compare its actual file identity.
inline std::optional<std::wstring> NormalizeLocalDirectory(
    std::wstring path) {
  for (auto& character : path) {
    if (character == L'/') character = L'\\';
  }
  if (path.compare(0, 4, L"\\\\?\\") == 0) path.erase(0, 4);
  while (path.size() > 3 && path.back() == L'\\') path.pop_back();
  if (path.size() <= 3 || path.size() >= 32768 ||
      !((path[0] >= L'A' && path[0] <= L'Z') ||
        (path[0] >= L'a' && path[0] <= L'z')) ||
      path[1] != L':' || path[2] != L'\\') {
    return std::nullopt;
  }
  size_t component_start = 3;
  for (size_t i = 3; i <= path.size(); ++i) {
    if (i == path.size() || path[i] == L'\\') {
      if (i == component_start || path[i - 1] == L'.' ||
          path[i - 1] == L' ') {
        return std::nullopt;
      }
      component_start = i + 1;
    } else if (path[i] < L' ' || path[i] == L'"' || path[i] == L':' ||
               path[i] == L'<' || path[i] == L'>' || path[i] == L'|' ||
               path[i] == L'?' || path[i] == L'*') {
      return std::nullopt;
    }
  }
  return path;
}

// Missing registrations contribute no evidence. Broken/inaccessible evidence
// cannot be treated as absence. Registrations for another directory never
// convert the running portable copy into an installed copy.
inline Classification Classify(bool executable_directory_trusted,
                               const std::vector<Evidence>& evidence) {
  if (!executable_directory_trusted) return {};
  Classification result{Kind::kPortable, Scope::kNone};
  for (const auto& entry : evidence) {
    if (entry.directory_relation == DirectoryRelation::kUnresolved) return {};
    if (entry.directory_relation == DirectoryRelation::kDifferent) continue;
    if ((entry.kind != Kind::kSetup && entry.kind != Kind::kMsi) ||
        (entry.kind == Kind::kSetup && entry.scope == Scope::kNone)) {
      return {};
    }
    const auto scope = entry.kind == Kind::kSetup ? entry.scope : Scope::kNone;
    if (result.kind != Kind::kPortable &&
        (result.kind != entry.kind || result.scope != scope)) {
      return {};
    }
    result = {entry.kind, scope};
  }
  return result;
}

inline const char* KindName(Kind kind) {
  switch (kind) {
    case Kind::kSetup: return "setup";
    case Kind::kMsi: return "msi";
    case Kind::kPortable: return "portable";
    default: return "unknown";
  }
}

}  // namespace windows_installation

#endif  // RUNNER_WINDOWS_INSTALLATION_POLICY_H_
