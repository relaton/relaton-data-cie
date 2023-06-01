# frozen_string_literal: true

require 'fileutils'
require 'relaton_cie'

FileUtils.rm_rf('data')
FileUtils.rm_f('index*')

RelatonCie::DataFetcher.fetch
