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
        return join(array(map!(a => a.render(indent + 1))(this.children)));
    }
}

struct Attribute
{
    string key;
    string value;
}


class TagNode: Node
{
    auto TAG_RE = ctRegex!(`%(?P<tag_name>\w[\w#\.\-]*)(\((?P<attrs>.+)\))?(?P<value_insert>=)?(?P<remainder>.+)?`);
    auto ATTR_SINGLE_RE = ctRegex!(`^(?P<key>\w+):\s*'(?P<value>.+?)',?`);
    auto ATTR_DOUBLE_RE = ctRegex!(`^(?P<key>\w+):\s*\"(?P<value>.+?)\",?`);
    auto TAG_CLASS_RE = ctRegex!(`\.(?P<class>\w[\w\-]*)`);
    auto TAG_NAME_RE = ctRegex!(`(?P<name>\w+)`);
    auto TAG_ID_RE = ctRegex!(`#(?P<id>\w[\w\-]*)`);

    Attribute[] attrs;
    string tag_name;
    bool is_value_insert;
    string remainder;


    this(string line, Node* parent = null)
    {
        super(line, parent);
        auto matched_tag = matchFirst(this.line, this.TAG_RE);
        this.tag_name = matched_tag["tag_name"];
        this.parse_tag();
        this.handle_shortcuts();
    }

    void parse_tag()
    {
        auto tag_cap = matchFirst(this.line, this.TAG_RE);
        this.tag_name = tag_cap["tag_name"];
        auto attrs = tag_cap["attrs"];
        this.is_value_insert = tag_cap["value_insert"] == "=";
        this.remainder = tag_cap["remainder"];
        while (attrs.length)
        {
            auto attr_cap = matchFirst(attrs, this.ATTR_SINGLE_RE);
            if (attr_cap.empty)
            {
                attr_cap = matchFirst(attrs, this.ATTR_DOUBLE_RE);
            }
            auto key = attr_cap["key"];
            auto value = attr_cap["value"];

            this.attrs ~= Attribute(key, value);

            attrs = attr_cap.post().stripLeft();
        }
    }

    void handle_shortcuts()
    {
        auto tag_string = this.tag_name[];
        auto tag_name_cap = matchFirst(tag_string, TAG_NAME_RE);
        this.tag_name = tag_name_cap["name"];
        tag_string = tag_name_cap.post();

        string[] classes;
        string tag_id = "";
        while (tag_string.length)
        {
            auto tag_class_cap = matchFirst(tag_string, TAG_CLASS_RE);
            if (!tag_class_cap.empty)
            {
                classes ~= tag_class_cap["class"];
                tag_string = tag_class_cap.post();
                continue;
            }
            auto tag_id_cap = matchFirst(tag_string, TAG_ID_RE);
            if (!tag_id_cap.empty)
            {
                tag_id = tag_id_cap["id"];
                tag_string = tag_id_cap.post();
                continue;
            }
            else
            {
                auto e = new Exception("Failed to parse special shortcuts.");
                throw e;
            }
        }
        if (classes.length)
            this.attrs ~= Attribute("class", join(classes, " "));
        if (tag_id.length)
            this.attrs ~= Attribute("id", tag_id);

    }

    override string render(int indent=0)
    {
        auto start = render_tag_start(indent);
        auto childs = "";
        auto close = "";
        if (this.remainder.length && this.children.length)
            childs = " ";
        if (this.children.length)
            childs ~= super.render(indent);
        if (this.children.length || this.remainder)
            close = this.render_closing_tag(indent, true);
        return start ~ childs ~ close;
    }

    string render_tag_start(int indent)
    {
        auto html = [leftJustify("\n", "\n".length + indent * this.indent_width)];
        html ~= "<" ~ this.tag_name;
        if (this.attrs.length)
        {
            html ~= " ";
            string[] evaluated_attrs;
            foreach(attr; this.attrs)
            {
                evaluated_attrs ~= attr.key ~ "=\"" ~ attr.value ~ "\"";
            }
            html ~= join(evaluated_attrs);
        }
        if (this.children.length || this.remainder)
            html ~= this.render_tag_end(false);
        else
            html ~= this.render_tag_end(true);
        if (this.remainder)
            html ~= this.remainder;
        return join(html, "");
    }


    string render_tag_end(bool one_line)
    {
        if (one_line)
            return " />";
        else
            return ">";
    }

    string render_closing_tag(int indent, bool new_line=false)
    {
        string[] res;
        if (new_line)
            res ~= ["\n", leftJustify("", indent * this.indent_width)];
        res ~= ["</", this.tag_name, ">"];
        return join(res, "");
    }

    unittest
    {
        auto t = new TagNode("%foobar");
        assert(t.tag_name == "foobar", t.tag_name);
    }

    unittest
    {
        auto t = new TagNode("%foobar.baz.spam");
        assert(t.tag_name == "foobar");
        assert(t.attrs[0].key == "class");
        assert(t.attrs[0].value == "baz spam");
    }

    unittest
    {
        auto t = new TagNode("%foobar#baz");
        assert(t.tag_name == "foobar");
        assert(t.attrs[0].key == "id");
        assert(t.attrs[0].value == "baz");
    }

    unittest
    {
        auto t = new TagNode("%foobar(src: 'meh', href: \"baz\")");
        assert(t.attrs[0].key == "src");
        assert(t.attrs[0].value == "meh");
        assert(t.attrs[1].key == "href");
        assert(t.attrs[1].value == "baz");
    }

    unittest
    {
        auto t = new TagNode("%foobar");
        auto ot = new TagNode("%p");
        t.add_child(ot);

        auto rendered = t.render();
        assert(rendered == "\n<foobar>\n    <p>\n    </p>\n</foobar>", "\"" ~ tr(rendered, " ", ".") ~ "\"");
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
