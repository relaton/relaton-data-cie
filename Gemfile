# frozen_string_literal: true
source "https://rubygems.org"

# Structured, pubid-typed index-v2 producer. The CIE data fetcher now lives in
# the relaton monorepo, and index rows are Pubid::Cie::Identifier objects, so
# pubid must carry the CIE grammar extensions (proceedings papers, techstreet
# /slug variant, D-series, etc.). Both are now merged upstream, so we track main.
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"
gem "pubid",   git: "https://github.com/metanorma/pubid.git", branch: "main"
