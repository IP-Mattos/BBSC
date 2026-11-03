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

// Every address in [lo, hi) where `needle` sits in committed, readable memory (at most max_hits).
// Slow (a full walk of the address range): call it once, off the game thread.
std::vector<std::uint64_t> FindInMemory(std::span<const std::uint8_t> needle, std::uint64_t lo,
                                        std::uint64_t hi, std::size_t max_hits);

// Several needles in ONE walk of the range (BBSC 2026-11-03): the hits of needle i, in address order,
// come back as {i, address}, at most max_hits_each per needle, so the result holds exactly what one
// FindInMemory call per needle would. Needles that share their first two bytes are searched with an
// SSE2 anchor on that prefix; otherwise it falls back to a walk per needle. Slow (a full walk of the
// address range): call it once, off the game thread.
std::vector<std::pair<std::size_t, std::uint64_t>> FindAnyInMemory(
    std::span<const std::span<const std::uint8_t>> needles, std::uint64_t lo, std::uint64_t hi,
    std::size_t max_hits_each);

} // namespace Core::Bbsc
