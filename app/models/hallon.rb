require 'cgi'

module Hallon
  # coding: utf-8


  # Search allows you to search Spotify for tracks, albums
  # and artists, just like in the client.
  #
  # @see http://developer.spotify.com/en/libspotify/docs/group__search.html
  class Search < Base
    # Enumerates through all tracks of a search object.
    class Tracks < Enumerator
      size :search_num_tracks

      # @return [Track, nil]
      item :search_track do |track|
        Track.from(track)
      end

      # @return [Integer] total number of tracks from connected search result.
      def total
        Spotify.search_total_tracks(pointer)
      end
    end

    # Enumerates through all albums of a search object.
    class Albums < Enumerator
      size :search_num_albums

      # @return [Album, nil]
      item :search_album do |album|
        Album.from(album)
      end

      # @return [Integer] total number of tracks from connected search result.
      def total
        Spotify.search_total_albums(pointer)
      end
    end

    # Enumerates through all albums of a search object.
    class Artists < Enumerator
      size :search_num_artists

      # @return [Artist, nil]
      item :search_artist do |artist|
        Artist.from(artist)
      end

      # @return [Integer] total tracks available from connected search result.
      def total
        Spotify.search_total_artists(pointer)
      end
    end

    # Enumerates through all playlists of a search object.
    class PlaylistEnumerator < Enumerator
      size :search_num_playlists

      # @return [Integer] total playlists available from connected search result.
      def total
        Spotify.search_total_playlists(pointer)
      end
    end

    # Enumerates through all playlist names of a search object.
    class PlaylistNames < PlaylistEnumerator
      # @return [String, nil]
      item :search_playlist_name
    end

    # Enumerates through all playlist uris of a search object.
    class PlaylistUris < PlaylistEnumerator
      # @return [String, nil]
      item :search_playlist_uri
    end

    # Enumerates through all playlist image uris of a search object.
    class PlaylistImageUris < PlaylistEnumerator
      # @return [String, nil]
      item :search_playlist_image_uri
    end

    # Enumerates through all playlists of a search object.
    class Playlists < PlaylistEnumerator
      # @return [Playlist]
      item :search_playlist_uri do |uri|
        Playlist.from(uri)
      end
    end

    # Enumerates through all playlist images of a search object.
    class Images < PlaylistEnumerator
      # @return [Playlist]
      item :search_playlist_image_uri do |uri|
        Image.from(uri)
      end
    end

    include Linkable

    to_link :from_search

    from_link :search do |link|
      link = Link.new(link).to_uri
      ::CGI.unescape(link[/\Aspotify:search:(.+)\z/m, 1])
    end

    extend Observable::Search
    include Loadable

    # @return [Hash] default search parameters
    def self.defaults
      @defaults ||= {
        :tracks  => 25,
        :albums  => 25,
        :artists => 25,
        :playlists => 25,
        :tracks_offset  => 0,
        :albums_offset  => 0,
        :artists_offset => 0,
        :playlists_offset => 0,
        :type => :standard
      }
    end

    # Construct a new search with given query.
    #
    # Given enough results for a given query, all searches are paginated by libspotify.
    # If the current number of results (say `search.tracks.size`) is less than the total
    # number of results (`search.tracks.total`), there are more results available. To
    # retrieve the additional tracks, you’ll need to do the same search query again, but
    # with a higher `tracks_offset`.
    #
    # @example searching tracks by offset
    #   search = Hallon::Search.new("genre:rock", tracks: 10, tracks_offset: 0).load
    #   search.tracks.size # => 10
    #   search.tracks.total # => 17
    #
    #   again  = Hallon::Search.new("genre:rock", tracks: 10, tracks_offset: 10).load
    #   again.tracks.size # => 7
    #   again.tracks.total # => 17
    #
    # @param [String, Link] search search query or spotify URI
    # @param [Hash] options additional search options
    # @option options [Symbol] :type (:standard) search type, either standard or suggest
    # @option options [#to_i] :tracks (25) max number of tracks you want in result
    # @option options [#to_i] :albums (25) max number of albums you want in result
    # @option options [#to_i] :artists (25) max number of artists you want in result
    # @option options [#to_i] :playlists (25) max number of playlists you want in result
    # @option options [#to_i] :tracks_offset (0) offset of tracks in search result
    # @option options [#to_i] :albums_offset (0) offset of albums in search result
    # @option options [#to_i] :artists_offset (0) offset of artists in search result
    # @option options [#to_i] :playlists_offset (0) offset of playlists in search result
    # @see http://developer.spotify.com/en/libspotify/docs/group__search.html#gacf0b5e902e27d46ef8b1f40e332766df
    def initialize(search, options = {})
      opts = Search.defaults.merge(options)
      type = opts.delete(:type)
      opts = opts.values_at(:tracks_offset, :tracks, :albums_offset, :albums, :artists_offset, :artists, :playlists_offset, :playlists).map(&:to_i)
      search = from_link(search) if Link.valid?(search)

      subscribe_for_callbacks do |callback|
        @pointer = if search.is_a?(Spotify::Search)
          search
        else
          Spotify.search_create(session.pointer, search, *opts, type, callback, nil)
        end

        raise ArgumentError, "search with #{search} failed" if @pointer.null?
      end
    end

    # @return [Boolean] true if the search has been fully loaded.
    def loaded?
      Spotify.search_is_loaded(pointer)
    end

    # @see Error.explain
    # @return [Symbol] search error status.
    def status
      Spotify.search_error(pointer)
    end

    # @return [String] search query this search was created with.
    def query
      Spotify.search_query(pointer).to_s
    end

    # @return [String] “did you mean?” suggestion for current search.
    def did_you_mean
      Spotify.search_did_you_mean(pointer).to_s
    end

    # @return [Tracks] list of all tracks in the search result.
    def tracks
      Tracks.new(self)
    end

    # @return [Albums] list of all albums in the search result.
    def albums
      Albums.new(self)
    end

    # @return [Artists] list of all artists in the search result.
    def artists
      Artists.new(self)
    end

    # @return [PlaylistNames] list of all playlist names in the search result.
    def playlist_names
      PlaylistNames.new(self)
    end

    # @return [PlaylistUris] list of all playlist uris in the search result.
    def playlist_uris
      PlaylistUris.new(self)
    end

    # @return [PlaylistImageUris] list of all playlist image uris in the search result.
    def playlist_image_uris
      PlaylistImageUris.new(self)
    end

    # @return [Playlists] list of all playlists in the search result.
    def playlists
      Playlists.new(self)
    end

    # @return [Images] list of all images in the search result.
    def playlist_images
      Images.new(self)
    end
  end

  class Artist < Base
    include Linkable
    include Loadable

    from_link :as_artist
    to_link   :from_artist

    
    def initialize(link)
      @pointer = to_pointer(link, Spotify::Artist)
    end

    # @return [String] name of the artist.
    def name
      Spotify.artist_name(pointer)
    end

    # @return [Boolean] true if the artist is loaded.
    def loaded?
      Spotify.artist_is_loaded(pointer)
    end

    # @see portrait_link
    # @param [Symbol] size (see {Image.sizes})
    # @return [Image, nil] artist portrait as an Image.
    def portrait(size = :normal)
      portrait = Spotify.artist_portrait(pointer, size)
      Image.from(portrait)
    end

    # @see portrait
    # @param [Symbol] size (see {Image.sizes})
    # @return [Link, nil] artist portrait as a Link.
    def portrait_link(size = :normal)
      portrait = Spotify.link_create_from_artist_portrait(pointer, size)
      Link.from(portrait)
    end

    # Browse the Artist, giving you the ability to explore its’
    # portraits, biography and more.
    #
    # @param [Symbol] type browsing type (see {ArtistBrowse.types})
    # @return [ArtistBrowse] an artist browsing object
    def browse(type = :full)
      ArtistBrowse.new(pointer, type)
    end
  end
end