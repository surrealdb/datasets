CREATE place:surreal_library SET name = "Surreal Library", address = "2025 Statement Street, Riverdale", place_type = "library", floors = 8;
CREATE town:riverdale SET name = "Riverdale", population = 75000, libraries = [place:surreal_library];

DEFINE FIELD address ON place TYPE string;
DEFINE FIELD name ON place TYPE string; DEFINE FIELD name ON town TYPE string;
DEFINE FIELD population ON town TYPE int;
DEFINE FIELD libraries ON town TYPE option<array<record<place>>>;
DEFINE FIELD place_type ON place TYPE "building" | "tower" | "store" | "school" | "park" | "library";
DEFINE FIELD OVERWRITE population ON town TYPE int ASSERT $value >= 0;

FOR $person IN [ { age: 30, name: 'Sara Bellum' }, { age: 25, name: 'Lydia Wyndham' }, { age: 45, name: 'Samm Schwartz' } ] { LET $created = CREATE ONLY person SET age = $person.age, name = $person.name; RELATE $created->works_at->place:surreal_library; };

DEFINE FIELD account_created ON TABLE customer_of VALUE time::now() READONLY;
DEFINE FIELD last_updated ON TABLE customer_of VALUE time::now();
DEFINE FIELD customer_for ON TABLE customer_of VALUE <future> { time::now() - account_created };

FOR $data IN [ { age: 15, name: 'Archie Andrews' }, { age: 15, name: 'Veronica Lodge' }, { age: 15, name: 'Betty Cooper' }, { age: 15, name: 'Jughead Jones'}, { age: 15, name: 'Reggie Mantle'}, { age: 50, name: 'Hiram P. Lodge' }, { age: 55, name: 'Geraldine Grundy' }, { age: 65, name: 'Waldo Weatherbee' } ] { LET $person = CREATE ONLY person SET name = $data.name, age = $data.age; RELATE $person->customer_of->place:surreal_library; };

FOR $data IN [ { author: 'Charles Dickens', english_title: 'A Tale of Two Cities', language: 'en', published: "1859-11-26", title: 'A Tale of Two Cities' }, { author: "Antoine de Saint-Exupéry", english_title: "The Little Prince", language: "fr", published: "1943-04-15", title: "Le Petit Prince" }, { author: 'Paulo Coelho', english_title: 'The Alchemist', language: 'pt', published: "1988-03-01", title: 'O Alquimista' }, { author: 'J.K. Rowling', english_title: "Harry Potter and the Philosopher's Stone", language: 'en', published: "1997-06-26", title: "Harry Potter and the Philosopher's Stone" }, { author: 'Agatha Christie', english_title: 'And Then There Were None', language: 'en', published: "1939-11-06", title: 'And Then There Were None' }, { author: 'Cao Xueqin', english_title: 'Dream of the Red Chamber', language: 'zh', published: "1791-03-01", title: '紅樓夢' }, { author: 'J.R.R. Tolkien', english_title: 'The Hobbit', language: 'en', published: "1937-09-21", title: 'The Hobbit' }, { author: 'Lewis Carroll', english_title: "Alice's Adventures in Wonderland", language: 'en', published: "1865-07-04", title: "Alice's Adventures in Wonderland" } ] { LET $author = CREATE ONLY person SET name = $data.author; LET $book = CREATE ONLY book SET author = $data.author, english_title = $data.english_title, language = $data.language, published = <datetime>$data.published, title = $data.title; RELATE $author->wrote->$book; RELATE place:surreal_library->has->$book; };

DEFINE FIELD author ON book TYPE string;
DEFINE FIELD language ON book TYPE string;
DEFINE FIELD title ON book TYPE string;

DEFINE EVENT language_check ON book WHEN $event = "CREATE" THEN { IF $after.language = 'en' { UPDATE $after SET english_title = $after.title; } ELSE IF $after.language != 'en' AND $after.english_title IS NONE { THROW "Please enter an English title for " + <string>$after.title + " written in " + <string>$after.language; } };

CREATE book SET title = "The Shadow Rising", author = "Robert Jordan", language = 'en';

DEFINE INDEX unique_address ON TABLE place FIELDS address UNIQUE;

DEFINE TABLE OVERWRITE works_at TYPE RELATION IN person OUT place;
DEFINE TABLE OVERWRITE wrote TYPE RELATION IN person OUT book;
DEFINE TABLE OVERWRITE has TYPE RELATION IN place OUT book;
DEFINE TABLE OVERWRITE customer_of TYPE RELATION IN person OUT place;