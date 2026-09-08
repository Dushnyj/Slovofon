#ifndef RUNNER_WINDOWS_ACTIVATION_H_
#define RUNNER_WINDOWS_ACTIVATION_H_

#include <cstdint>
#include <deque>
#include <optional>
#include <string>
#include <vector>

namespace windows_activation {

using Arguments = std::vector<std::string>;
constexpr size_t kMaximumPacketBytes = 128 * 1024;
constexpr size_t kMaximumArguments = 256;
constexpr size_t kMaximumPendingBytes = 1024 * 1024;
constexpr size_t kMaximumPendingActivations = 32;
constexpr uint32_t kProtocolVersion = 1;
constexpr uintptr_t kCopyDataTag = 0x534c5641;  // SLVA

inline bool ValidUtf8(const std::string& value) {
  size_t i = 0;
  while (i < value.size()) {
    const auto first = static_cast<unsigned char>(value[i++]);
    if (first == 0) return false;
    if (first < 0x80) continue;
    unsigned int extra = 0;
    uint32_t code = 0;
    if (first >= 0xc2 && first <= 0xdf) { extra = 1; code = first & 0x1f; }
    else if (first >= 0xe0 && first <= 0xef) { extra = 2; code = first & 0x0f; }
    else if (first >= 0xf0 && first <= 0xf4) { extra = 3; code = first & 0x07; }
    else return false;
    if (value.size() - i < extra) return false;
    for (unsigned int j = 0; j < extra; ++j) {
      const auto next = static_cast<unsigned char>(value[i++]);
      if ((next & 0xc0) != 0x80) return false;
      code = (code << 6) | (next & 0x3f);
    }
    if ((extra == 2 && code < 0x800) || (extra == 3 && code < 0x10000) ||
        (code >= 0xd800 && code <= 0xdfff) || code > 0x10ffff) return false;
  }
  return true;
}

inline void AppendWord(std::vector<uint8_t>& bytes, uint32_t value) {
  for (int shift = 0; shift < 32; shift += 8) {
    bytes.push_back(static_cast<uint8_t>((value >> shift) & 0xff));
  }
}

inline std::optional<std::vector<uint8_t>> Encode(const Arguments& arguments) {
  if (arguments.size() > kMaximumArguments) return std::nullopt;
  std::vector<uint8_t> bytes;
  AppendWord(bytes, kProtocolVersion);
  AppendWord(bytes, static_cast<uint32_t>(arguments.size()));
  for (const auto& argument : arguments) {
    if (!ValidUtf8(argument) || argument.size() > kMaximumPacketBytes ||
        bytes.size() + 4 + argument.size() > kMaximumPacketBytes) {
      return std::nullopt;
    }
    AppendWord(bytes, static_cast<uint32_t>(argument.size()));
    bytes.insert(bytes.end(), argument.begin(), argument.end());
  }
  return bytes;
}

inline std::optional<Arguments> Decode(const void* data, size_t size) {
  if (!data || size < 8 || size > kMaximumPacketBytes) return std::nullopt;
  const auto* bytes = static_cast<const uint8_t*>(data);
  size_t offset = 0;
  const auto read_word = [&]() -> std::optional<uint32_t> {
    if (size - offset < 4) return std::nullopt;
    uint32_t value = 0;
    for (int shift = 0; shift < 32; shift += 8) {
      value |= static_cast<uint32_t>(bytes[offset++]) << shift;
    }
    return value;
  };
  const auto version = read_word();
  const auto count = read_word();
  if (!version || *version != kProtocolVersion || !count ||
      *count > kMaximumArguments) return std::nullopt;
  Arguments result;
  for (uint32_t i = 0; i < *count; ++i) {
    const auto length = read_word();
    if (!length || *length > size - offset) return std::nullopt;
    std::string argument(reinterpret_cast<const char*>(bytes + offset), *length);
    if (!ValidUtf8(argument)) return std::nullopt;
    offset += *length;
    result.push_back(std::move(argument));
  }
  if (offset != size) return std::nullopt;
  return result;
}

// Owned by the platform thread. Never silently evict a pending deep link.
class PendingActivations {
 public:
  bool Add(Arguments arguments) {
    if (arguments.empty()) return true;  // A plain shortcut only restores HWND.
    const auto encoded = Encode(arguments);
    if (!encoded || queue_.size() >= kMaximumPendingActivations ||
        bytes_ + encoded->size() > kMaximumPendingBytes) return false;
    bytes_ += encoded->size();
    queue_.push_back(std::move(arguments));
    return true;
  }

  std::deque<Arguments> Take() {
    bytes_ = 0;
    std::deque<Arguments> result;
    result.swap(queue_);
    return result;
  }

 private:
  size_t bytes_ = 0;
  std::deque<Arguments> queue_;
};

}  // namespace windows_activation

#endif  // RUNNER_WINDOWS_ACTIVATION_H_
