module Intrigue
module Task
class SearchCrt < BaseTask
  include Intrigue::Task::Web

  def self.metadata
    {
      :name => "search_crt",
      :pretty_name => "Search CRT",
      :authors => ["jcran"],
      :description => "This task hit CRT's API and creates new DnsRecord entities.",
      :references => ["https://www.virustotal.com/en/documentation/"],
      :type => "discovery",
      :passive => true,
      :allowed_types => ["DnsRecord"],
      :example_entities => [ {"type" => "DnsRecord", "details" => {"name" => "intrigue.io"}} ],
      :allowed_options => [
        {:name => "extract_pattern", :type => "String", :regex => "alpha_numeric", :default => false },
        {:name => "gather_subdomains", :type => "Boolean", :regex => "boolean", :default => true }
      ],
      :created_types => ["DnsRecord"]
    }
  end

  def run
    super

    search_domain = _get_entity_name
    opt_gather_subdomains = _get_option "gather_subdomains"
    opt_extract_pattern = _get_option("extract_pattern") == "false"

    if opt_gather_subdomains
      crt_query_uri = "https://crt.sh/?q=#{search_domain}"
      begin

        # gather all related certs
        html = Nokogiri::HTML(http_get_body(crt_query_uri))
        cert_ids = html.xpath("//td/a/@href").map do |x|
          x.to_s.gsub("\n","").strip
        end

        # individually query certs
        cert_ids.each do |cert_id|
          crt_cert_uri = "https://crt.sh/"
          raw_html = http_get_body("#{crt_cert_uri}#{cert_id}&opt=nometadata")

          next if raw_html =~ /cloudflare/i # run and hide

          raw_html.scan(/DNS:(.*?)<BR>/).each do |domains|
            domains.each do |dname|
              _log "Found domain: #{dname}"

              # If we have an extract pattern set, respect it
              if opt_extract_pattern
                next unless dname =~ /#{opt_extract_pattern}/
              end

              _create_entity("DnsRecord", "name"=> dname )
            end
          end

        end
      rescue StandardError => e
        _log_error "Error grabbing crt domains: #{e}"
      end
    end

  end

end
end
end
