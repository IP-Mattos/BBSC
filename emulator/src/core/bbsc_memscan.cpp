// SPDX-FileCopyrightText: Copyright 2026 CLS_AMG
// SPDX-License-Identifier: GPL-2.0-or-later

#include "core/bbsc_memscan.h"

#ifdef _WIN32
#include <windows.h>
#include <emmintrin.h>
#include <intrin.h>
#endif

#include <cstring>

namespace Core::Bbsc {

namespace {

#ifdef _WIN32
// One region. The emulator changes page protection all the time (GPU tracking), so a page that was
// readable a moment ago may fault now: the search runs under SEH and a fault just ends the region.
void SearchRegion(const std::uint8_t* start, std::size_t size, const std::uint8_t* needle,
                  std::size_t length, std::vector<std::uint64_t>& hits, std::size_t max_hits) {
    __try {
        const std::uint8_t* end = start + size;
        const std::uint8_t* at = start;
        while (hits.size() < max_hits && end - at >= static_cast<std::ptrdiff_t>(length)) {
            at = static_cast<const std::uint8_t*>(
                std::memchr(at, needle[0], static_cast<std::size_t>(end - at) - length + 1));
            if (at == nullptr) {
                break;
            }
            if (std::memcmp(at, needle, length) == 0) {
                hits.push_back(reinterpret_cast<std::uint64_t>(at));
            }
            ++at;
        }
    } __except (EXCEPTION_EXECUTE_HANDLER) {
    }
}

// `anchor` = 2 or 3 bytes every needle shares, 16 positions at a time. A fault ends the region.
void SearchRegionMany(const std::uint8_t* start, std::size_t size,
                      std::span<const std::span<const std::uint8_t>> needles, std::size_t anchor,
                      std::vector<std::vector<std::uint64_t>>& hits, std::size_t max_hits_each) {
    const auto check = [&](const std::uint8_t* at, const std::uint8_t* end) {
        for (std::size_t i = 0; i < needles.size(); ++i) {
            const auto& needle = needles[i];
            if (hits[i].size() < max_hits_each &&
                static_cast<std::size_t>(end - at) >= needle.size() &&
                std::memcmp(at, needle.data(), needle.size()) == 0) {
                hits[i].push_back(reinterpret_cast<std::uint64_t>(at));
            }
        }
    };
    const auto full = [&] {
        for (const auto& found : hits) {
            if (found.size() < max_hits_each) {
                return false;
            }
        }
        return true;
    };
    __try {
        const std::uint8_t* end = start + size;
        const std::uint8_t* at = start;
        const __m128i b0 = _mm_set1_epi8(static_cast<char>(needles[0][0]));
        const __m128i b1 = _mm_set1_epi8(static_cast<char>(needles[0][1]));
        const __m128i b2 = _mm_set1_epi8(static_cast<char>(needles[0][anchor - 1]));
        // 16 candidates per step; the loads reach at most 17 bytes past `at`.
        while (!full() && end - at >= 19) {
            __m128i match = _mm_and_si128(
                _mm_cmpeq_epi8(_mm_loadu_si128(reinterpret_cast<const __m128i*>(at)), b0),
                _mm_cmpeq_epi8(_mm_loadu_si128(reinterpret_cast<const __m128i*>(at + 1)), b1));
            if (anchor == 3) {
                match = _mm_and_si128(
                    match, _mm_cmpeq_epi8(
                               _mm_loadu_si128(reinterpret_cast<const __m128i*>(at + 2)), b2));
            }
            unsigned mask = static_cast<unsigned>(_mm_movemask_epi8(match));
            while (mask != 0) {
                unsigned long bit = 0;
                _BitScanForward(&bit, mask);
                check(at + bit, end);
                mask &= mask - 1;
            }
            at += 16;
        }
        for (; !full() && at < end; ++at) {
            if (*at == needles[0][0]) {
                check(at, end);
            }
        }
    } __except (EXCEPTION_EXECUTE_HANDLER) {
    }
}
#endif

} // namespace

std::vector<std::uint64_t> FindInMemory(std::span<const std::uint8_t> needle, std::uint64_t lo,
                                        std::uint64_t hi, std::size_t max_hits) {
    std::vector<std::uint64_t> hits;
#ifdef _WIN32
    if (needle.empty()) {
        return hits;
    }
    constexpr DWORD Readable = PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READ |
                               PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY;
    std::uint64_t at = lo;
    while (at < hi && hits.size() < max_hits) {
        MEMORY_BASIC_INFORMATION info{};
        if (VirtualQuery(reinterpret_cast<void*>(at), &info, sizeof(info)) == 0) {
            break;
        }
        const auto start = reinterpret_cast<std::uint64_t>(info.BaseAddress);
        const std::uint64_t end = start + info.RegionSize;
        if (info.State == MEM_COMMIT && (info.Protect & Readable) != 0 &&
            (info.Protect & (PAGE_GUARD | PAGE_NOACCESS)) == 0) {
            SearchRegion(reinterpret_cast<const std::uint8_t*>(start), info.RegionSize,
                         needle.data(), needle.size(), hits, max_hits);
        }
        if (end <= at) {
            break;
        }
        at = end;
    }
#endif
    return hits;
}

std::vector<std::pair<std::size_t, std::uint64_t>> FindAnyInMemory(
    std::span<const std::span<const std::uint8_t>> needles, std::uint64_t lo, std::uint64_t hi,
    std::size_t max_hits_each) {
    std::vector<std::pair<std::size_t, std::uint64_t>> out;
#ifdef _WIN32
    if (needles.empty()) {
        return out;
    }
    std::size_t anchor = 3; // leading bytes every needle shares, at most 3
    for (const auto& needle : needles) {
        if (needle.empty()) {
            return out;
        }
        std::size_t same = 0;
        while (same < anchor && same < needle.size() && needle[same] == needles[0][same]) {
            ++same;
        }
        anchor = same;
    }
    std::vector<std::vector<std::uint64_t>> hits(needles.size());
    if (anchor < 2) { // no shared prefix
        for (std::size_t i = 0; i < needles.size(); ++i) {
            hits[i] = FindInMemory(needles[i], lo, hi, max_hits_each);
        }
    } else {
        constexpr DWORD Readable = PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY |
                                   PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE |
                                   PAGE_EXECUTE_WRITECOPY;
        std::uint64_t at = lo;
        while (at < hi) {
            bool full = true;
            for (const auto& found : hits) {
                full = full && found.size() >= max_hits_each;
            }
            if (full) {
                break;
            }
            MEMORY_BASIC_INFORMATION info{};
            if (VirtualQuery(reinterpret_cast<void*>(at), &info, sizeof(info)) == 0) {
                break;
            }
            const auto start = reinterpret_cast<std::uint64_t>(info.BaseAddress);
            const std::uint64_t end = start + info.RegionSize;
            if (info.State == MEM_COMMIT && (info.Protect & Readable) != 0 &&
                (info.Protect & (PAGE_GUARD | PAGE_NOACCESS)) == 0) {
                SearchRegionMany(reinterpret_cast<const std::uint8_t*>(start), info.RegionSize,
                                 needles, anchor, hits, max_hits_each);
            }
            if (end <= at) {
                break;
            }
            at = end;
        }
    }
    for (std::size_t i = 0; i < hits.size(); ++i) {
        for (const std::uint64_t address : hits[i]) {
            out.emplace_back(i, address);
        }
    }
#endif
    return out;
}

} // namespace Core::Bbsc
