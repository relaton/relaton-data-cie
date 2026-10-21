# frozen_string_literal: true

require 'fileutils'
require 'relaton/cie/data_fetcher'

# Incremental crawl: keep data/ and let the fetcher skip byte-identical
# records and prune stale ones (relaton#328).
Relaton::Cie::DataFetcher.fetch(prune: true)
