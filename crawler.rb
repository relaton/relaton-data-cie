# frozen_string_literal: true

require 'fileutils'
require 'relaton_cie'

FileUtils.rm_rf('data')

RelatonCie::DataFetcher.fetch

system("git add data flag.txt")
