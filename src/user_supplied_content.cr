require "xml"
require "markd"

struct UserSuppliedContent
  private getter source

  # These are Tuples instead of Arrays so that it would be immutable at runtime
  ALLOWED_TAGS = {
    "a",
    "abbr",
    "aside",
    "b",
    "blockquote",
    "br",
    "code",
    "details",
    "em",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "hr",
    "i",
    "img",
    "kbd",
    "li",
    "ol",
    "p",
    "pre",
    "small",
    "span",
    "strong",
    "sub",
    "summary",
    "sup",
    "u",
    "ul",
  }

  ALLOWED_ATTRIBUTES = {
    "href",
    "src",
    "alt",
  }

  PARSE_OPTIONS = XML::HTMLParserOptions::RECOVER |
                  XML::HTMLParserOptions::NODEFDTD |
                  XML::HTMLParserOptions::NOBLANKS |
                  XML::HTMLParserOptions::NOIMPLIED |
                  XML::HTMLParserOptions::COMPACT

  OUTPUT_OPTIONS = XML::SaveOptions::AS_HTML |
                   XML::SaveOptions::NO_DECL

  def initialize(@source : String)
  end

  def to_html : String
    html = XML.parse_html(Markd.to_html(source), options: PARSE_OPTIONS)

    html.xpath_nodes("//*").each do |node|
      node.unlink unless ALLOWED_TAGS.includes? node.name.downcase
      node.attributes.each do |attribute|
        # This is needed for syntax highlighting so we're allowing it.
        next if node.name == "code" && attribute.name == "class"

        unless ALLOWED_ATTRIBUTES.includes? attribute.name
          node.delete attribute.name
        end
      end

      case node.name.downcase
      when /^h[1-6]$/ # Headings h1-h6
        node["id"] = node.content.downcase.gsub(/\W+/, '-')
      end
    end

    html.to_xml(options: OUTPUT_OPTIONS)
  end
end
