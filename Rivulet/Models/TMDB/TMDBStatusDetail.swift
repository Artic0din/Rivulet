//
//  TMDBStatusDetail.swift
//  Rivulet
//
//  ADO-04 — status/schedule fields decoded from the standard TMDb detail
//  payload (`GET /3/tv/{id}` and `/3/movie/{id}`, reached via the app's
//  `tmdb/details/{id}` proxy). These fields already exist on that response; this
//  is a decode-only model isolated from `TMDBItemDetail` so the broader detail
//  model and its custom coder are untouched. Every field is optional and decoded
//  defensively — TMDb omits most of them for movies and for incomplete records,
//  and the backend proxy may project a subset (see DEBT-E3-ADO03-001).
//

import Foundation

/// Minimal episode reference from `next_episode_to_air` / `last_episode_to_air`.
nonisolated struct TMDBEpisodeRef: Decodable, Sendable, Equatable {
    let airDate: String?
    let seasonNumber: Int?
    let episodeNumber: Int?

    enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
    }
}

/// Minimal season reference from `seasons[]`.
nonisolated struct TMDBSeasonRef: Decodable, Sendable, Equatable {
    let airDate: String?
    let episodeCount: Int?
    let seasonNumber: Int?

    enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case episodeCount = "episode_count"
        case seasonNumber = "season_number"
    }
}

/// Status/schedule slice of a TMDb detail response. Decoded from the same JSON
/// as `TMDBItemDetail`; used only to build a `ContentStatusInput`.
nonisolated struct TMDBStatusDetail: Decodable, Sendable, Equatable {
    // Common
    let status: String?            // TV: "Returning Series"/"Ended"/… ; Movie: "Released"/"Post Production"/…
    let releaseDate: String?       // movie
    // TV
    let inProduction: Bool?
    let firstAirDate: String?
    let lastAirDate: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let nextEpisodeToAir: TMDBEpisodeRef?
    let lastEpisodeToAir: TMDBEpisodeRef?
    let seasons: [TMDBSeasonRef]?

    enum CodingKeys: String, CodingKey {
        case status
        case releaseDate = "release_date"
        case inProduction = "in_production"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case nextEpisodeToAir = "next_episode_to_air"
        case lastEpisodeToAir = "last_episode_to_air"
        case seasons
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try? c.decode(String.self, forKey: .status)
        releaseDate = try? c.decode(String.self, forKey: .releaseDate)
        inProduction = try? c.decode(Bool.self, forKey: .inProduction)
        firstAirDate = try? c.decode(String.self, forKey: .firstAirDate)
        lastAirDate = try? c.decode(String.self, forKey: .lastAirDate)
        numberOfSeasons = try? c.decode(Int.self, forKey: .numberOfSeasons)
        numberOfEpisodes = try? c.decode(Int.self, forKey: .numberOfEpisodes)
        nextEpisodeToAir = try? c.decode(TMDBEpisodeRef.self, forKey: .nextEpisodeToAir)
        lastEpisodeToAir = try? c.decode(TMDBEpisodeRef.self, forKey: .lastEpisodeToAir)
        seasons = try? c.decode([TMDBSeasonRef].self, forKey: .seasons)
    }

    /// Memberwise init for tests / synthesis.
    init(
        status: String? = nil,
        releaseDate: String? = nil,
        inProduction: Bool? = nil,
        firstAirDate: String? = nil,
        lastAirDate: String? = nil,
        numberOfSeasons: Int? = nil,
        numberOfEpisodes: Int? = nil,
        nextEpisodeToAir: TMDBEpisodeRef? = nil,
        lastEpisodeToAir: TMDBEpisodeRef? = nil,
        seasons: [TMDBSeasonRef]? = nil
    ) {
        self.status = status
        self.releaseDate = releaseDate
        self.inProduction = inProduction
        self.firstAirDate = firstAirDate
        self.lastAirDate = lastAirDate
        self.numberOfSeasons = numberOfSeasons
        self.numberOfEpisodes = numberOfEpisodes
        self.nextEpisodeToAir = nextEpisodeToAir
        self.lastEpisodeToAir = lastEpisodeToAir
        self.seasons = seasons
    }
}
