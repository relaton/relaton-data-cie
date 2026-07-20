# frozen_string_literal: true
source "https://rubygems.org"

# Structured, pubid-typed index-v2 producer. The CIE data fetcher now lives in
# the relaton monorepo, and index rows are Pubid::Cie::Identifier objects, so
# pubid must carry the CIE grammar extensions (proceedings papers, techstreet
# /slug variant, D-series, etc.).
#
# Switch both branches to "main"/"master" once the work is merged upstream.
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "feat/cie-pubid-index-v2"
gem "pubid",   git: "https://github.com/metanorma/pubid.git", branch: "feat/cie-proceedings-and-grammar-extensions"
