# frozen_string_literal: true

require 'fileutils'
require 'relaton/cie/data_fetcher'

FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')

Relaton::Cie::DataFetcher.fetch
