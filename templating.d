import std.stdio;
import std.algorithm.iteration: map;
import std.array: array, join;


class Node
{
    Node[] children;
    string line;
    Node* parent;

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

    string render(int indent)
    {
        return join(array(map!(a => a.render(indent))(this.children)));
    }
}

class TextNode: Node
{
    this(string line, Node* parent = null)
    {
        super(line, parent);
    }

    override string render(int indent)
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
