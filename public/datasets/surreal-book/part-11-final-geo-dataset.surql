DEFINE FIELD name ON TABLE town TYPE string;
DEFINE FIELD old_name ON TABLE town TYPE option<string>;
DEFINE FIELD population ON TABLE town TYPE option<int>;
DEFINE FIELD location ON TABLE town TYPE geometry<point>;
DEFINE INDEX unique_town ON TABLE town FIELDS name UNIQUE;

DEFINE FIELD crookedness ON TABLE to TYPE "straight" | "crooked" | "very crooked";
DEFINE FIELD terrain     ON TABLE to TYPE "road" | "normal"  | "hard" | "water";
DEFINE FIELD slope       ON TABLE to TYPE "flat" | "up" | "down" | "steep";

DEFINE FIELD bearing ON TABLE to
    VALUE geo::bearing(in.location, out.location);

DEFINE INDEX unique_key ON TABLE to FIELDS in, out UNIQUE;

INSERT INTO town [
-- Telegraph places
{ name: "Toria",          old_name: "Victoria",                      population: 7000,  location: (-123.338, 48.481) },
{ name: "Sukh",           old_name: "Sooke",                         population: 1200,  location: (-123.723, 48.377) },
{ name: "Black Bay",      old_name: "Swartz Bay",                    population: 1100,  location: (-123.414, 48.688) },
{ name: "The Hill",       old_name: "Duncan (Cobble Hill)",          population: 1100,  location: (-123.601, 48.688) },
{ name: "Honeymoon",      old_name: "Honeymoon Bay (Lake Cowichan)", population: 200,   location: (-124.051, 48.823) },
{ name: "The Naimo",      old_name: "Nanaimo",                       population: 9500,  location: (-123.908, 49.185) },
{ name: "Gaston",         old_name: "Vancouver",                     population: 20000, location: (-123.100, 49.278) },
{ name: "Abeston",        old_name: "Abbotsford",                    population: 1000,  location: (-122.328, 49.079) },
{ name: "Hope",           old_name: "Hope",                          population: 50,    location: (-121.459, 49.388) },
{ name: "Princeton",      old_name: "Princeton",                     population: 200,   location: (-120.481, 49.473) },
{ name: "Merit",          old_name: "Merritt",                       population: 250,   location: (-120.758, 50.144) },
{ name: "Copper Creek",   old_name: "Kamloops",                      population: 2400,  location: (-120.329, 50.677) },
{ name: "Lake Country",   old_name: "Kelowna",                       population: 2500,  location: (-119.513, 49.940) },
{ name: "Southlake",      old_name: "Penticton",                     population: 500,   location: (-119.570, 49.515) },
{ name: "Grasslands",     old_name: "Osoyoos",                       population: 120,   location: (-119.472, 49.033) },
{ name: "Marysville",     old_name: "Marysville",                    population: 50,    location: (-122.199, 48.081) },
{ name: "Revelry",        old_name: "Revelstoke",                    population: 123,   location: (-118.100, 51.050) },
{ name: "Redmont",        old_name: "Seattle (Redmond)",             population: 30000, location: (-122.282, 47.682) },
-- No telegraph places
{ name: "Bulton",         old_name: "Calgary",                       population: 6000,  location: (-113.867, 51.182) },
{ name: "Edmond's Field", old_name: "Edmonton",                      population: 6000,  location: (-113.602, 53.697) }
];

FOR $trip IN [
 { from: "The Naimo",      to: "The Hill",       crookedness: "straight",     terrain: "road",  slope: "up"    },
 { from: "The Hill",       to: "The Naimo",      crookedness: "straight",     terrain: "road",  slope: "down"  },
 { from: "Honeymoon",      to: "The Hill",       crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "The Hill",       to: "Honeymoon",      crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "The Hill",       to: "Toria",          crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Toria",          to: "The Hill",       crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Black Bay",      to: "Toria",          crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Toria",          to: "Black Bay",      crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Sukh",           to: "Toria",          crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Toria",          to: "Sukh",           crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Toria",          to: "Marysville",     crookedness: "straight",     terrain: "water", slope: "flat"  },
 { from: "Marysville",     to: "Toria",          crookedness: "straight",     terrain: "water", slope: "flat"  },
 { from: "Redmont",        to: "Marysville",     crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Marysville",     to: "Redmont",        crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Black Bay",      to: "Gaston",         crookedness: "crooked",      terrain: "water", slope: "flat"  },
 { from: "Gaston",         to: "Black Bay",      crookedness: "crooked",      terrain: "water", slope: "flat"  },
 { from: "Gaston",         to: "Abeston",        crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Abeston",        to: "Gaston",         crookedness: "straight",     terrain: "road",  slope: "flat"  },
 { from: "Gaston",         to: "Redmont",        crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Redmont",        to: "Gaston",         crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Abeston",        to: "Hope",           crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Hope",           to: "Abeston",        crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Hope",           to: "Merit",          crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Merit",          to: "Hope",           crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Hope",           to: "Princeton",      crookedness: "very crooked", terrain: "road",  slope: "flat" },
 { from: "Princeton",      to: "Hope",           crookedness: "very crooked", terrain: "road",  slope: "flat" },
 { from: "Princeton",      to: "Grasslands",     crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Grasslands",     to: "Princeton",      crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Southlake",      to: "Grasslands",     crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Grasslands",     to: "Southlake",      crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Southlake",      to: "Lake Country",   crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Lake Country",   to: "Southlake",      crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Merit",          to: "Lake Country",   crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Lake Country",   to: "Merit",          crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Merit",          to: "Copper Creek",   crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Copper Creek",   to: "Merit",          crookedness: "crooked",      terrain: "road",  slope: "flat" },
 { from: "Copper Creek",   to: "Revelry",        crookedness: "very crooked", terrain: "road",  slope: "flat" },
 { from: "Revelry",        to: "Copper Creek",   crookedness: "very crooked", terrain: "road",  slope: "flat" },
 { from: "Revelry",        to: "Bulton",         crookedness: "very crooked", terrain: "road",  slope: "flat" },
 { from: "Bulton",         to: "Revelry",        crookedness: "very crooked", terrain: "road",  slope: "flat" },
 { from: "Bulton",         to: "Edmond's Field", crookedness: "straight",     terrain: "road",  slope: "flat" },
 { from: "Edmond's Field", to: "Bulton",         crookedness: "straight",     terrain: "road",  slope: "flat" },
] {
LET $begin = (SELECT * FROM ONLY town WHERE name = $trip.from LIMIT 1);
LET $end =   (SELECT * FROM ONLY town WHERE name = $trip.to LIMIT 1);
RELATE $begin->to->$end
    SET
    crookedness = $trip.crookedness,
    terrain = $trip.terrain,
    slope = $trip.slope,
    distance = geo::distance($begin.location, $end.location),
    speed_modifier = 
        (IF     crookedness = "straight"     { 1.0 }
        ELSE IF crookedness = "crooked"      { 0.8 }
        ELSE IF crookedness = "very crooked" { 0.5 })
        *
        (IF     slope = "flat"               { 1.0 }
        ELSE IF slope = "up"                 { 0.8 }
        ELSE IF slope = "down"               { 1.2 }
        ELSE IF slope = "steep"              { 0.5 }        
        )
        *
        (IF terrain = "road"                 { 1.2 }
        ELSE IF terrain = "normal"           { 1.0 }
        ELSE IF terrain = "hard"             { 0.7 }
        ELSE IF terrain = "water"            { 1.0 }
        )
        ,
    // if land, then 20 km per day * modifier
    // if water, assume one day of wait then 100 km per day * modifier
    days_travel = 
        IF $trip.terrain = "water" { 1 + (distance / 100000) / speed_modifier }
        ELSE                       {      (distance / 20000)  / speed_modifier  }
};

DEFINE FUNCTION fn::add_trip($from: string, $to: string, $crookedness: string, $terrain: string, $slope: string) -> string {
    IF $crookedness NOT IN ["straight", "crooked", "very crooked"] {
    THROW "Third argument is crookedness: straight, crooked, or very crooked";
    };
    IF $terrain NOT IN ["road", "normal", "land", "water"] {
        THROW "Fourth argument is terrain: road, normal, land, or water";
    };
    IF $slope NOT IN ["flat", "up", "down", "steep"] {
      THROW "Fifth argument is slope: flat, up, down, or steep";  
    };
    LET $begin = (SELECT * FROM ONLY town WHERE name = $from LIMIT 1);
    LET $end =   (SELECT * FROM ONLY town WHERE name = $to LIMIT 1);

    IF count($begin) = 0 {
        THROW "Could not find town " + $from + " in the database"
    };

    IF count($end) = 0 {
        THROW "Could not find town " + $to + " in the database"
    };

    LET $relation = RELATE $begin->to->$end
        SET
        crookedness = $crookedness,
        terrain = $terrain,
        slope = $slope,
        distance = geo::distance($begin.location, $end.location),
        speed_modifier = 
            (IF     crookedness = "straight"     { 1.0 }
            ELSE IF crookedness = "crooked"      { 0.8 }
            ELSE IF crookedness = "very crooked" { 0.5 })
            *
            (IF     slope = "flat"               { 1.0 }
            ELSE IF slope = "up"                 { 0.8 }
            ELSE IF slope = "down"               { 1.2 }
            ELSE IF slope = "steep"              { 0.5 })
            *
            (IF terrain = "road"                 { 1.2 }
            ELSE IF terrain = "normal"           { 1.0 }
            ELSE IF terrain = "hard"             { 0.7 }
            ELSE IF terrain = "water"            { 1.0 }),
        days_travel = 
            IF $trip.terrain = "water" { 1 + (distance / 100000 * speed_modifier) }
            ELSE                       {      distance / 20000  * speed_modifier  };
    RETURN <string>$relation.in.name + " to " + <string>$relation.out.name + " trip created!";
};



-- Uncomment + paste into https://csacademy.com/app/graph_editor/ to see a nice graph/node representation

-- Toria
-- Sukh
-- Black_Bay
-- The_Hill
-- Honeymoon
-- The_Naimo
-- Gaston
-- Abeston
-- Hope
-- Princeton
-- Merit
-- Revelry
-- Copper_Creek
-- Lake_Country
-- Southlake
-- Grasslands
-- Marysville
-- Bulton
-- Edmonds_Field
-- Redmont
-- Toria Sukh
-- Toria Black_Bay
-- Toria The_Hill
-- Toria Marysville
-- The_Hill Honeymoon
-- The_Hill The_Naimo
-- Black_Bay Gaston
-- Gaston Abeston
-- Abeston Hope
-- Hope Princeton
-- Hope Merit
-- Princeton Grasslands
-- Merit Copper_Creek
-- Merit Lake_Country
-- Lake_Country Revelry
-- Copper_Creek Revelry
-- Revelry Bulton
-- Bulton Edmonds_Field
-- Lake_Country Southlake
-- Southlake Grasslands
-- Marysville Redmont

