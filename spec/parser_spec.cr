require "./spec_helper"

describe Parser do
  it "parses raw text" do
    txt = "raw text"
    template = Parser.parse txt
    expected = [Block::Raw.new("raw text")]
    template.root.children.should eq expected
  end

  it "parses raw blocks" do
    txt = "PRE {% raw %}test\nIn Handlebars, {{ this }} will be HTML-escaped, but {{{ that }}} will not.{% endraw %} POST"
    template = Parser.parse txt
    expected = [
      Block::Raw.new("PRE "),
      Block::Raw.new("test\nIn Handlebars, {{ this }} will be HTML-escaped, but {{{ that }}} will not."),
      Block::Raw.new(" POST"),
    ]
    template.root.children.should eq expected

    txt = " PRE {%- raw -%} RAW  {% endraw %} POST "
    template = Parser.parse txt
    expected = [
      Block::Raw.new(" PRE"),
      Block::Raw.new(" RAW  "),
      Block::Raw.new("POST "),
    ]
    template.root.children.should eq expected
  end

  it "should allow to escape statement" do
    txt = "\\{% assign mavar = 12 %}"
    template = Liquid::Parser.parse txt
    template.render(Context.new).should eq txt
  end

  it "should allow to escape expressions" do
    txt = "\\{{ assign mavar = 12 }}"
    template = Liquid::Parser.parse txt
    template.render(Context.new).should eq txt
  end

  it "parses for loop" do
    txt = "{% for x in 0..2 %} shown 2 times {% endfor %}"
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    expected << Block::For.new("for x in 0..2")
    expected.last << Block::Raw.new(" shown 2 times ")

    template.root.children.should eq expected
  end

  it "parses if statement" do
    txt = "{% if a == true %} shown {% endif %}"
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    expected << Block::If.new("if a == true")
    expected.last << Block::Raw.new(" shown ")

    template.root.children.should eq expected
  end

  it "parses if else statement" do
    txt = "{% if a == true %} shown {% else %} not shown {% endif %}"
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    if_node = Block::If.new("if a == true")
    if_node << Block::Raw.new(" shown ")
    else_node = Block::Else.new("")
    else_node << Block::Raw.new(" not shown ")
    if_node << else_node
    expected << if_node

    template.root.children.should eq expected
  end

  it "parses case statement" do
    txt = <<-STRING
            {% case desert %}
              {% when "cake" %} This is a cake
              {% when "cookie", "biscuit" %} This is a cookie
              {% else %} This is not a cake nor a cookie
            {% endcase %}
            STRING

    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    case_node = Block::Case.new("case desert")
    case_node << Block::Raw.new("\n  ")
    when_node = Block::When.new("when \"cake\"")
    when_node << Block::Raw.new(" This is a cake\n  ")
    case_node << when_node
    when_node = Block::When.new("when \"cookie\", \"biscuit\"")
    when_node << Block::Raw.new(" This is a cookie\n  ")
    case_node << when_node
    else_node = Block::Else.new("")
    else_node << Block::Raw.new(" This is not a cake nor a cookie\n")
    case_node << else_node
    expected << case_node

    template.root.children.should eq expected
  end

  it "trims lspace in statements" do
    txt = " PRE \t\n{%- if a == true %} \t\nPOST "
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    expected << Block::Raw.new(" PRE")
    expected << Block::If.new("if a == true")
    expected.last << Block::Raw.new(" \t\nPOST ")

    template.root.children.should eq expected
  end

  it "trims rspace in statements" do
    txt = " PRE \t\n{% if a == true -%} \t\nPOST "
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    expected << Block::Raw.new(" PRE \t\n")
    expected << Block::If.new("if a == true")
    expected.last << Block::Raw.new("POST ")

    template.root.children.should eq expected
  end

  it "trims lspace in expressions" do
    txt = " PRE \t\n{{- assign mavar = 12 }} \t\nPOST "
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    expected << Block::Raw.new(" PRE")
    expected << Block::Expression.new("assign mavar = 12")
    expected << Block::Raw.new(" \t\nPOST ")

    template.root.children.should eq expected
  end

  it "trims rspace in expressions" do
    txt = " PRE \t\n{{ assign mavar = 12 -}} \t\nPOST "
    template = Liquid::Parser.parse txt

    expected = [] of Block::Node
    expected << Block::Raw.new(" PRE \t\n")
    expected << Block::Expression.new("assign mavar = 12")
    expected << Block::Raw.new("POST ")

    template.root.children.should eq expected
  end
end
