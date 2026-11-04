// SPDX-FileCopyrightText: Copyright 2026 CLS_AMG
// SPDX-License-Identifier: GPL-2.0-or-later

// BBSC: find bytes in the game's memory (the param tables are found by their header text). Kept
// out of bloodborne_re.cpp so <windows.h> stays out of it. Shared by the emulator and the mod DLL.

#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <utility>
#include <vector>

namespace Core::Bbsc {

// An address range: a memory region as the OS reports it, or a stretch to look at first.
struct ScanWindow {
    std::uint64_t base = 0;
    std::uint64_t size = 0;
};

// Every address in [lo, hi) where `needle` sits in committed, readable memory (at most max_hits).
// Slow (a full walk of the address range): call it once, off the game thread.
std::vector<std::uint64_t> FindInMemory(std::span<const std::uint8_t> needle, std::uint64_t lo,
                                        std::uint64_t hi, std::size_t max_hits);

// One walk for several needles: {i, address}, in address order per needle, at most max_hits_each each.
// SSE2 needs 2+ shared leading bytes, else one walk per needle. Slow: once, off the game thread.
// `hit_regions`, when given, gets one entry per result (same order): the region that held the hit
// (zero size when the per-needle fallback ran).
std::vector<std::pair<std::size_t, std::uint64_t>> FindAnyInMemory(
    std::span<const std::span<const std::uint8_t>> needles, std::uint64_t lo, std::uint64_t hi,
    std::size_t max_hits_each, std::vector<ScanWindow>* hit_regions = nullptr);

// The same one-pass search over `windows` only (the part of each region inside it). Needs 2+ shared
// leading bytes, else nothing is searched. Cost follows the window sizes.
std::vector<std::pair<std::size_t, std::uint64_t>> FindAnyInWindows(
    std::span<const std::span<const std::uint8_t>> needles, std::span<const ScanWindow> windows,
    std::size_t max_hits_each, std::vector<ScanWindow>* hit_regions = nullptr);

} // namespace Core::Bbsc
