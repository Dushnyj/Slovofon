#include "../windows_activation.h"

#include <cassert>
#include <iostream>

using namespace windows_activation;

int main() {
  const Arguments input{"", "slovofon://book?source=izib&book=4331",
                        u8"Белые ночи / Қазақша / Українська", "--not-executed"};
  const auto bytes = Encode(input);
  assert(bytes && Decode(bytes->data(), bytes->size()) == input);
  const auto empty = Encode({});
  assert(empty && Decode(empty->data(), empty->size()) == Arguments{});
  assert(!Decode(nullptr, 100));
  for (size_t length = 0; length < bytes->size(); ++length) {
    assert(!Decode(bytes->data(), length));
  }
  auto trailing = *bytes;
  trailing.push_back(1);
  assert(!Decode(trailing.data(), trailing.size()));
  auto wrong_version = *bytes;
  wrong_version[0] = 99;
  assert(!Decode(wrong_version.data(), wrong_version.size()));
  auto overflow = *bytes;
  for (size_t index = 4; index < 8; ++index) overflow[index] = 255;
  assert(!Decode(overflow.data(), overflow.size()));
  for (size_t index = 8; index < 12; ++index) overflow[index] = 255;
  overflow[4] = 1; overflow[5] = 0; overflow[6] = 0; overflow[7] = 0;
  assert(!Decode(overflow.data(), overflow.size()));

  assert(!Encode(Arguments(kMaximumArguments + 1, "x")));
  assert(!Encode({std::string(kMaximumPacketBytes, 'x')}));
  assert(!Encode({std::string("a\0b", 3)}));
  for (const auto& invalid : {std::string("\xc0\xaf", 2),
                              std::string("\xed\xa0\x80", 3),
                              std::string("\xf4\x90\x80\x80", 4),
                              std::string("\xe2\x82", 2),
                              std::string("\x80", 1)}) {
    assert(!Encode({invalid}));
    auto malformed = *Encode({"a"});
    malformed.back() = 0x80;
    assert(!Decode(malformed.data(), malformed.size()));
  }
  assert(ValidUtf8(u8"😀"));
  PendingActivations queue;
  assert(queue.Add({}));
  assert(queue.Take().empty());
  for (size_t i = 0; i < kMaximumPendingActivations; ++i) {
    assert(queue.Add({std::to_string(i)}));
  }
  assert(!queue.Add({"must not evict older links"}));
  const auto pending = queue.Take();
  assert(pending.size() == kMaximumPendingActivations);
  for (size_t i = 0; i < pending.size(); ++i) {
    assert(pending[i] == Arguments{std::to_string(i)});
  }
  assert(queue.Take().empty());
  for (int i = 0; i < 8; ++i) assert(queue.Add({std::string(120000, 'x')}));
  assert(!queue.Add({std::string(120000, 'x')}));
  assert(queue.Take().size() == 8);
  assert(queue.Add({"capacity restored"}));
  std::cout << "Windows activation codec and bounded queue: PASS\n";
}
