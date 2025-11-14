-- Chapter 5
DEFINE TABLE person SCHEMAFULL;
DEFINE TABLE building SCHEMAFULL;
DEFINE FIELD name ON table person TYPE string;
DEFINE FIELD class ON table person TYPE option<string>;
DEFINE FIELD money ON TABLE person 
    TYPE option<int>
    ASSERT $value >= 0 OR $value IS NONE;
DEFINE FIELD name ON TABLE person 
    TYPE string 
    ASSERT $value.replace(" ", "").replace("-", "").is_alpha();
DEFINE FIELD kind ON TABLE building 
    TYPE string
    ASSERT 
    ["house", "castle"] CONTAINS $value;
DEFINE FIELD properties ON TABLE person TYPE option<array<record<building>>> REFERENCE;
CREATE person:the_nobleman SET 
    name = "The Nobleman",
    class = "Count",
    money = 50;
CREATE building:old_castle SET
  name = "Old castle",
  kind = "castle";
UPDATE person:the_nobleman SET properties = [building:old_castle];

-- Chapter 6
CREATE person:the_noblewoman SET
    name = "The Noblewoman",
    properties = [building:old_castle];
CREATE person:wulfield SET name = "Wulfield";
CREATE person:adelaide SET name = "Adelaide";
CREATE person:bertha SET name = "Bertha";
DEFINE FIELD between ON parent_of TYPE "mother-son" | "mother-daughter" | "father-son" | "father-daughter";
FOR $daughter IN [person:adelaide, person:bertha, person:wulfield] {
    RELATE person:the_nobleman->parent_of->$daughter SET between = "father-daughter";
    RELATE person:the_noblewoman->parent_of->$daughter SET between = "mother-daughter";
};

-- Chapter 7
INSERT INTO building [
    { id: "bear_castle",  name: "Bear castle",  kind: "castle" },
    { id: "eagle_castle", name: "Eagle castle", kind: "castle" },
    { id: "fish_castle",  name: "Fish castle",  kind: "castle" },
];

INSERT INTO person [
    { id: "bear_knight",  name: "Bear knight",  money: 100000, properties: [building:bear_castle ] },
    { id: "eagle_knight", name: "Eagle knight", money: 200000, properties: [building:eagle_castle] },
    { id: "fish_knight",  name: "Fish knight",  money: 500000, properties: [building:fish_castle]  },
];
RELATE person:eagle_knight->married->person:adelaide;
RELATE person:wulfield->married->person:bear_knight;
RELATE person:bertha->married->person:fish_knight;
RELATE person:the_nobleman->married->person:the_noblewoman;

-- Chapter 8
CREATE person:grandmother SET 
    name = "Mother of the Nobleman",
    feeling = "Disappointed in son";
RELATE person:grandmother->parent_of->person:the_nobleman SET between = "mother-son";
CREATE person:reginald SET name = "Reginald";
RELATE [person:the_nobleman, person:the_noblewoman]->parent_of->person:reginald;
CREATE person:sorcerer SET name = "Zornebock";
RELATE [
    person:reginald,
    person:bear_knight,
    person:eagle_knight,
    person:fish_knight
]->enemy_of->person:sorcerer;