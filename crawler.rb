# frozen_string_literal: true

require 'fileutils'
require 'relaton_cie'

FileUtils.rm_rf('data')
FileUtils.rm Dir.glob('index*')

RelatonCie::DataFetcher.fetch
