# frozen_string_literal: true

# Jekyll generator that creates vanity URL redirect pages at build time
# from the entries defined in _data/redirects.yml.
#
# Pages are created with a `redirect_to` data attribute so that the
# jekyll-redirect-from gem (bundled with github-pages) handles the
# actual redirect HTML output.  This generator only needs to:
#
#   1. Materialise a page for each entry.
#   2. Validate that no vanity URL conflicts with an existing page or post.
#
# Priority is set to :high so the pages exist in site.pages before the
# jekyll-redirect-from generator (which runs at :normal) processes them.

module Jekyll
  class VanityRedirectsGenerator < Generator
    safe true
    priority :high

    def generate(site)
      redirects = site.data["redirects"]
      return unless redirects.is_a?(Array) && !redirects.empty?

      validate(site, redirects)

      redirects.each do |entry|
        from = entry["from"]
        to   = entry["to"]
        next unless from && to

        page = PageWithoutAFile.new(site, site.source, "", "#{from}.html")
        page.data["redirect_to"] = to
        page.data["sitemap"]     = false
        site.pages << page
      end
    end

    private

    def validate(site, redirects)
      # Build a map of every URL path already claimed by pages and posts.
      existing = {}

      site.pages.each do |page|
        url = normalise(page.url)
        existing[url] = page.relative_path
      end

      site.posts.docs.each do |post|
        url = normalise(post.url)
        existing[url] = post.relative_path
      end

      seen = {}

      redirects.each_with_index do |entry, idx|
        from = entry["from"]

        unless from
          log_error "Entry #{idx + 1} is missing the 'from' field."
          next
        end

        unless entry["to"]
          log_error "'#{from}' is missing the 'to' field."
        end

        url_key = "/#{from}"

        # Duplicate vanity URL
        if seen.key?(from)
          log_error "Duplicate vanity URL '/#{from}' " \
                    "(entries #{seen[from] + 1} and #{idx + 1})."
        else
          seen[from] = idx
        end

        # Overlap with an existing page or post
        if existing.key?(url_key)
          log_error "Vanity URL '/#{from}' conflicts with " \
                    "existing path '#{existing[url_key]}'."
        end
      end
    end

    def normalise(url)
      url = url.chomp("/")
      url = url.chomp("index.html").chomp("/")
      url.empty? ? "/" : url
    end

    def log_error(msg)
      Jekyll.logger.error "VanityRedirects:", msg
    end
  end
end
