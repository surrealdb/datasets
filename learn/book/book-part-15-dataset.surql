remove table citizen;
remove table country;

DEFINE TABLE country    TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD name ON TABLE country TYPE string;
DEFINE INDEX unique_country ON TABLE country FIELDS name UNIQUE;

DEFINE TABLE citizen    TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD name ON TABLE citizen TYPE string;
// Each country might define this diferently
DEFINE FIELD citizen_id ON TABLE citizen TYPE string;
DEFINE INDEX unique_citizen ON TABLE citizen FIELDS citizen_id UNIQUE;

DEFINE TABLE citizen_of TYPE RELATION 
    IN citizen 
    OUT country 
    SCHEMAFULL
    PERMISSIONS NONE;

DEFINE FUNCTION fn::create_citizen($country_name: string, $citizen_name: string, $citizen_id: option<string>) {

    LET $country = (SELECT * FROM ONLY country WHERE name = $country_name LIMIT 1);

    IF $citizen_id IS NOT NONE {
        LET $citizen = SELECT * FROM ONLY citizen WHERE citizen_id = $citizen_id LIMIT 1;
        RELATE $citizen->citizen_of->$country;
    } ELSE {
        LET $citizen_res = SELECT id FROM citizen WHERE name = $citizen_name;
        IF $citizen_res.len() != 1 {
            THROW "Expected a single citizen, got " + <string>$citizen_res
        } ELSE {
            LET $citizen = $citizen_res[0].id;
            RELATE $citizen->citizen_of->$country;
        }
    }    
};