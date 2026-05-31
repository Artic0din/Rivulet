# Media Validation Corpus

## Purpose

This corpus defines the minimum validation library required to prove playback correctness and parity across Rivulet’s supported routes and formats.

The corpus is a contract, not a wish list. Epic 4 and Epic 5 must use these sample classes as evidence anchors for playback claims.

## Corpus Rules

1. Every sample has a stable ID.
2. Every playback-related evidence record must cite sample IDs.
3. Samples may cover multiple requirements, but every required requirement below must be represented.
4. Device captures are required for HDR, Dolby Vision, Dolby Atmos, and Live TV validation.

## Coverage Map

| Required Coverage | Sample IDs |
| --- | --- |
| MP4 Direct Play | CORPUS-001, CORPUS-002 |
| MKV Direct Play | CORPUS-003 |
| MKV Remux | CORPUS-004, CORPUS-005, CORPUS-006 |
| HLS | CORPUS-007, CORPUS-008 |
| SDR | CORPUS-001, CORPUS-003, CORPUS-012 |
| HDR10 | CORPUS-002 |
| HDR10+ | CORPUS-009 |
| Dolby Vision | CORPUS-006 |
| Dolby Atmos | CORPUS-005 |
| AAC Stereo | CORPUS-001 |
| TrueHD | CORPUS-005 |
| SRT subtitles | CORPUS-010 |
| ASS subtitles | CORPUS-011 |
| PGS subtitles | CORPUS-012 |
| Large bitrate samples | CORPUS-013 |
| TV episodes | CORPUS-014 |
| Movies | CORPUS-001, CORPUS-002, CORPUS-005, CORPUS-006 |
| Live TV samples | CORPUS-015, CORPUS-016 |

## Sample Definitions

| Sample ID | Profile | Purpose | Validation Scenarios | Owning Epic | Required Evidence |
| --- | --- | --- | --- | --- | --- |
| CORPUS-001 | MP4, H.264 or HEVC SDR, AAC stereo, direct play | Baseline native playback path | Start playback, pause/resume, seek, resume from history, exit to UI | Epic 4 | Startup timing, seek timing, playback screenshot or video |
| CORPUS-002 | MP4, HEVC HDR10, E-AC-3 or AAC, direct play | Validate native HDR direct path | Start on device, verify dynamic range switching, pause/resume, exit | Epic 4 | Device capture, route note, startup timing |
| CORPUS-003 | MKV, HEVC SDR, AAC or AC-3, direct play eligible | Validate MKV direct-play path where AVPlayer is not forced to remux | Start, seek, subtitle off/on, return to detail | Epic 4 | Route confirmation, timing, subtitle toggle notes |
| CORPUS-004 | MKV, HEVC SDR, DTS or unsupported audio requiring remux | Validate local remux policy and stability | Start via remux, seek, background/foreground, exit | Epic 4 | Route confirmation, startup timing, recovery notes |
| CORPUS-005 | MKV, HEVC, TrueHD Atmos | Validate advanced audio handling and remux or fallback behavior | Start playback, verify track selection, resume, stop transcode/remux cleanly | Epic 4 | Device capture, route confirmation, audio track evidence |
| CORPUS-006 | MKV, HEVC Dolby Vision Profile 7 or 8.6 | Validate Dolby Vision route choice and fallback behavior | Start on device, verify route, seek, resume, exit | Epic 4 | Device capture, route note, error-free playback evidence |
| CORPUS-007 | Plex HLS fallback sample | Validate explicit HLS startup and controls | Start via HLS, seek, pause/resume, failure handling | Epic 4 | Startup timing, route evidence, controls evidence |
| CORPUS-008 | Forced HLS transcode under degraded direct-play conditions | Validate deterministic fallback and recovery | Simulate fallback, validate playback begins and failure messaging is coherent | Epic 4 | Failure and recovery notes, timing |
| CORPUS-009 | HDR10+ sample | Validate graceful handling of HDR10+ content | Start on device, verify route choice and user-visible result even if format is normalized or falls back | Epic 4 | Device capture, route evidence, outcome note |
| CORPUS-010 | Subtitle-focused sample with external or embedded SRT | Validate SRT timing and selection | Toggle subtitles, seek across cues, pause/resume, exit | Epic 4 | Subtitle screenshots, cue timing notes |
| CORPUS-011 | Subtitle-focused sample with ASS styling | Validate ASS styling and legibility | Toggle subtitles, verify styled rendering, seek and resume | Epic 4 | Subtitle screenshots, styling notes |
| CORPUS-012 | Subtitle-focused sample with PGS bitmaps | Validate bitmap subtitle handling | Toggle subtitles, verify bitmap visibility, seek and resume | Epic 4 | Subtitle screenshots, cue persistence notes |
| CORPUS-013 | High-bitrate 4K HEVC sample over HTTP | Validate `URLSessionAVIOSource` throughput path | Start playback, observe startup, seek, 10-minute stability run | Epic 4 | Route and throughput notes, startup timing, stability evidence |
| CORPUS-014 | Episodic TV sample with next-up/resume semantics | Validate episode progression and Continue Watching correctness | Play episode, exit midstream, resume, complete, handoff to next episode | Epic 2 and Epic 4 | Continue Watching evidence, playback evidence, detail handoff evidence |
| CORPUS-015 | Live TV direct sample via HDHomeRun | Validate direct Live TV path | Tune, change channel, recover from short interruption, exit | Epic 4 | Device or simulator capture, startup timing, channel-switch notes |
| CORPUS-016 | Live TV transcode sample via Plex DVB tuner path | Validate required transcode parameter path | Tune, validate startup, recover from interruption, exit | Epic 4 | Startup timing, transcode validation notes, error handling evidence |

## Sample Acquisition Requirements

The validation library must include:

- at least one movie sample for each applicable route
- at least one episodic sample with watch-state progression
- at least one subtitle sample for SRT, ASS, and PGS
- at least one device-only HDR or Dolby Vision sample
- at least one Live TV direct sample and one Live TV transcode sample

## Evidence Requirements

Each playback evidence record must include:

- sample ID
- device or simulator
- route type
- startup result
- seek result if applicable
- subtitle or track-change result if applicable
- screenshots or short video if user-visible behavior is being reviewed

## Acceptance Criteria

This document is acceptable when:

1. Every required media category is covered by at least one sample ID.
2. Each sample has clear purpose and validation scenarios.
3. Owning epic and evidence requirements are explicit.
4. Playback claims can be tied to corpus entries instead of informal “tested on some file” statements.
