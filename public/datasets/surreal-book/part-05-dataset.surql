DEFINE TABLE person SCHEMAFULL;
DEFINE TABLE building SCHEMAFULL;
DEFINE FIELD name ON TABLE person 
    TYPE string 
    ASSERT $value.replace(" ", "").replace("-", "").is_alpha();
DEFINE FIELD class ON table person TYPE option<string>;
DEFINE FIELD money ON TABLE person 
    TYPE option<int>
    ASSERT $value >= 0 OR $value IS NONE;
DEFINE FIELD name ON TABLE building TYPE string;
DEFINE FIELD kind ON TABLE building 
    TYPE string
    ASSERT 
    ["house", "castle"] CONTAINS $value;
DEFINE FIELD properties ON TABLE person TYPE option<array<record<building>>>;
CREATE person:the_nobleman SET 
    name = "The Nobleman",
    class = "Count",
    money = 50;
CREATE building:old_castle SET
  name = "Old castle",
  kind = "castle";
UPDATE person:the_nobleman SET properties = [building:old_castle];