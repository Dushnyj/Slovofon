#include "../windows_installation_policy.h"

#include <cassert>
#include <iostream>

int main() {
  using namespace windows_installation;
  using Relation = DirectoryRelation;

  assert(Classify(false, {}).kind == Kind::kUnknown);
  assert(Classify(true, {}).kind == Kind::kPortable);
  const Evidence user{Kind::kSetup, Scope::kUser, Relation::kSame};
  const Evidence machine{Kind::kSetup, Scope::kMachine, Relation::kSame};
  const Evidence msi{Kind::kMsi, Scope::kNone, Relation::kSame};
  const Evidence other_setup{Kind::kSetup, Scope::kMachine, Relation::kDifferent};
  const Evidence other_msi{Kind::kMsi, Scope::kNone, Relation::kDifferent};
  const Evidence broken{Kind::kMsi, Scope::kNone, Relation::kUnresolved};

  assert(Classify(true, {user}).kind == Kind::kSetup);
  assert(Classify(true, {user}).scope == Scope::kUser);
  assert(Classify(true, {machine}).scope == Scope::kMachine);
  assert(Classify(true, {msi}).kind == Kind::kMsi);
  assert(Classify(true, {msi}).scope == Scope::kNone);
  // Two registry views or marker + stable UpgradeCode can describe one install.
  assert(Classify(true, {user, user}).scope == Scope::kUser);
  assert(Classify(true, {msi, msi}).kind == Kind::kMsi);
  // A custom-path portable copy must remain portable next to an installed app.
  assert(Classify(true, {other_setup, other_msi}).kind == Kind::kPortable);
  assert(Classify(true, {user, other_msi}).kind == Kind::kSetup);
  assert(Classify(true, {other_setup, msi}).kind == Kind::kMsi);
  // Missing MSI InstallLocation, access errors and incompatible registrations
  // all fail closed, even if one other source appears to match successfully.
  assert(Classify(true, {broken}).kind == Kind::kUnknown);
  assert(Classify(true, {user, broken}).kind == Kind::kUnknown);
  assert(Classify(true, {broken, user}).kind == Kind::kUnknown);
  assert(Classify(true, {user, machine}).kind == Kind::kUnknown);
  assert(Classify(true, {user, msi}).kind == Kind::kUnknown);
  assert(Classify(true, {msi, machine}).kind == Kind::kUnknown);
  assert(Classify(true, {{Kind::kSetup, Scope::kNone, Relation::kSame}}).kind ==
         Kind::kUnknown);

  assert(NormalizeLocalDirectory(L"C:\\Program Files\\Slovofon\\") ==
         L"C:\\Program Files\\Slovofon");
  assert(NormalizeLocalDirectory(L"D:/Apps/Slovofon") == L"D:\\Apps\\Slovofon");
  assert(NormalizeLocalDirectory(L"\\\\?\\D:\\Apps\\Slovofon") ==
         L"D:\\Apps\\Slovofon");
  assert(NormalizeLocalDirectory(L"C:\\Books \\Slovofon") == std::nullopt);
  for (const auto* invalid : {
           L"", L"C:", L"C:\\", L"C:relative", L"Apps\\Slovofon",
           L"\\Apps\\Slovofon", L"\\\\server\\share\\Slovofon",
           L"\\\\?\\UNC\\server\\share", L"\\\\.\\C:\\Slovofon",
           L"C:\\Apps\\..\\Slovofon", L"C:\\Apps\\.\\Slovofon",
           L"C:\\Apps\\\\Slovofon", L"C:\\Apps\\Slovofon.",
           L"C:\\Apps\\Slovofon ", L"C:\\Apps\\Slovofon:stream",
           L"C:\\Apps\\\"Slovofon", L"C:\\Apps\\Slovofon\n",
           L"C:\\Apps\\*", L"C:\\Apps\\Slovofon|command"}) {
    assert(!NormalizeLocalDirectory(invalid));
  }
  assert(!NormalizeLocalDirectory(std::wstring(L"C:\\Apps\\x\0other", 15)));
  std::cout << "Windows installation policy tests passed.\n";
}
