class RebuildSearchJob < ApplicationJob
  queue_as :default

  # Calls a search rebuild, used when categories are updated
  def perform
    # FIXME: This is a temporary fix for the search index rebuild
    # PgSearch::Multisearch.rebuild(Doc)
  end
end
