import std.algorithm.iteration: map;
import std.array: array, join;
import std.regex;
import std.stdio;
import std.string;
import std.typetuple;

class Node
{
    Node[] children;
    string line;
    Node* parent;
    int indent_width = 4;

    this(string line, Node* parent = null)
    {
        this.line = line;
        this.parent = parent;
        if (parent)
            parent.add_child(this);
    }

    void add_child(Node child)
    {
        this.children ~= child;
    }

    string render(int indent=0)
    {
        return join(array(map!(a => a.render(indent))(this.children)));
    }
}

struct Attribute
{
    string key;
    string value;
}


class TagNode: Node
{
    auto tag_rex = ctRegex!(`%(?P<tag_name>\w[\w#\.\-]*)(\((?P<attrs>.+)\))?(?P<value_insert>=)?(?P<remainder>.+)?`);

    auto attr_single_rex = ctRegex!(`(?P<key>\w+):\s*'(?P<value>.+?)',?`);
    auto attr_double_rex = ctRegex!(`(?P<key>\w+):\s*\"(?P<value>.+?)\",?`);
    string tag_name;

    Attribute[] attrs;

    this(string line, Node* parent = null)
    {
        super(line, parent);
        auto matched_tag = matchFirst(this.line, this.tag_rex);
        this.tag_name = matched_tag["tag_name"];
        this.parse_tag();
    }

    void parse_tag()
    {
        auto tag_cap = matchFirst(this.line, this.tag_rex);
        this.tag_name = tag_cap["tag_name"];
        auto attrs = tag_cap["attrs"];
        while (attrs.length)
        {
            auto attr_cap = matchFirst(attrs, this.attr_single_rex);
            if (attr_cap.empty)
            {
                attr_cap = matchFirst(attrs, this.attr_double_rex);
            }
            auto key = attr_cap["key"];
            auto value = attr_cap["value"];

            this.attrs ~= Attribute(key, value);

            attrs = attr_cap.post().stripLeft();
        }
    }

    override string render(int indent=0)
    {
        auto pre = rightJustify(this.line, this.line.length + indent * this.indent_width);
        pre ~= "\n";
        auto inner = super.render(indent=indent+1);
        return pre ~ inner;
    }

    unittest
    {
        auto t = new TagNode("%foobar");
        assert(t.tag_name == "foobar", t.tag_name);
    }

    unittest
    {
        auto t = new TagNode("%foobar(src: 'meh')");
        assert(t.attrs[0].key == "src");
        assert(t.attrs[0].value == "meh");
    }

    unittest
    {
        auto t = new TagNode("%foobar");
        auto ot = new TagNode("%p");
        t.add_child(ot);

        auto rendered = t.render();
        assert(rendered == "<foobar>\n    <p>\n    </p>\n</foobar>", "\"" ~ rendered ~ "\"");
    }
}

class TextNode: Node
{
    this(string line, Node* parent = null)
    {
        super(line, parent);
    }

    override string render(int indent=0)
    {
        return this.line;
    }

    unittest
    {
        auto t = new TextNode("%body");
        assert(t.render(0) == "%body");
    }
}

unittest
{
    auto root = new Node("%html");
    auto child = new TextNode("%body", &root);

    assert(root.children == [child]);
}

unittest
{
    auto root = new Node("%html");
    auto child1 = new TextNode("%body", &root);
    auto child2 = new TextNode("%div", &root);
    assert(root.render(0) == "%body%div");
}

class Template
{
    string data;

    this(string data)
    {
        this.data = data;
    }

    string to_html(string haml_line)
    {
        return haml_line;
    }

    string render()
    {
        return this.data;
    }

    unittest
    {
        auto tmpl = new Template("Foobar");
        assert(tmpl.render() == "Foobar");
    }
};

int main()
{
    return 0;
}
