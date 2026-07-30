import Foundation

/// Hall of Fame name pool (English): people and characters an English-speaking
/// party crowd will recognise instantly. No difficulty tiers — an obscure name
/// stalls the yes/no question round.
enum HallOfFameNamesEN {

    static let pool: [String] = [
        // MARK: Music
        "Taylor Swift", "Beyoncé", "Michael Jackson", "Elvis Presley", "Adele",
        "Ed Sheeran", "Rihanna", "Lady Gaga", "Bruno Mars", "Eminem",
        "Bob Marley", "Freddie Mercury", "Madonna", "Prince", "David Bowie",
        "John Lennon", "Paul McCartney", "Mick Jagger", "Bob Dylan", "Elton John",
        "Whitney Houston", "Aretha Franklin", "Tina Turner", "Stevie Wonder", "Ray Charles",
        "Frank Sinatra", "Johnny Cash", "Dolly Parton", "Justin Bieber", "Ariana Grande",
        "Billie Eilish", "Drake", "Kanye West", "Jay-Z", "Snoop Dogg",
        "Bruce Springsteen", "Jimi Hendrix", "Kurt Cobain", "Amy Winehouse", "Shakira",
        "Jennifer Lopez", "Katy Perry", "Britney Spears", "Christina Aguilera", "Mariah Carey",
        "Céline Dion", "Harry Styles", "Dua Lipa", "The Weeknd", "Post Malone",
        "Miley Cyrus", "Selena Gomez", "Nicki Minaj", "Cardi B", "Pharrell Williams",
        "Usher", "Alicia Keys", "Luciano Pavarotti", "Andrea Bocelli", "Yo-Yo Ma",
        "Louis Armstrong", "Ella Fitzgerald", "Nina Simone", "Bono", "Ozzy Osbourne",

        // MARK: Film actors
        "Tom Cruise", "Leonardo DiCaprio", "Dwayne Johnson", "Keanu Reeves", "Morgan Freeman",
        "Will Smith", "Jackie Chan", "Marilyn Monroe", "Audrey Hepburn", "Charlie Chaplin",
        "Brad Pitt", "Angelina Jolie", "Johnny Depp", "Robert Downey Jr.", "Scarlett Johansson",
        "Jennifer Lawrence", "Meryl Streep", "Denzel Washington", "Samuel L. Jackson", "Tom Hanks",
        "Julia Roberts", "Sandra Bullock", "Nicole Kidman", "Anne Hathaway", "Emma Watson",
        "Emma Stone", "Natalie Portman", "Charlize Theron", "Halle Berry", "Reese Witherspoon",
        "Arnold Schwarzenegger", "Sylvester Stallone", "Bruce Willis", "Harrison Ford", "Clint Eastwood",
        "Robert De Niro", "Al Pacino", "Jack Nicholson", "Anthony Hopkins", "Ian McKellen",
        "Chris Hemsworth", "Chris Evans", "Chris Pratt", "Ryan Reynolds", "Ryan Gosling",
        "Matt Damon", "Ben Affleck", "George Clooney", "Hugh Jackman", "Christian Bale",
        "Jim Carrey", "Adam Sandler", "Eddie Murphy", "Steve Carell", "Bill Murray",
        "Robin Williams", "Rowan Atkinson", "Zendaya", "Timothée Chalamet", "Margot Robbie",
        "Gal Gadot", "Jason Statham", "Bruce Lee", "Jet Li", "Michelle Yeoh",
        "Idris Elba", "Daniel Craig", "Pierce Brosnan", "Sean Connery", "Tom Holland",
        "Millie Bobby Brown", "Danny DeVito", "John Travolta", "Whoopi Goldberg", "Viola Davis",

        // MARK: Directors
        "Steven Spielberg", "Quentin Tarantino", "Alfred Hitchcock", "Christopher Nolan", "Martin Scorsese",
        "James Cameron", "Walt Disney", "Stanley Kubrick", "Tim Burton", "Greta Gerwig",

        // MARK: TV, comedy, media
        "Oprah Winfrey", "Ellen DeGeneres", "Jimmy Fallon", "Jimmy Kimmel", "Conan O'Brien",
        "David Letterman", "Stephen Colbert", "Trevor Noah", "John Oliver", "Simon Cowell",
        "Gordon Ramsay", "Bear Grylls", "David Attenborough", "Anderson Cooper", "Kim Kardashian",
        "Paris Hilton", "Martha Stewart", "Kevin Hart", "Chris Rock", "Dave Chappelle",
        "Ricky Gervais", "Tina Fey", "Amy Poehler", "Jerry Seinfeld", "Bob Ross",

        // MARK: Sport
        "Michael Jordan", "LeBron James", "Kobe Bryant", "Stephen Curry", "Shaquille O'Neal",
        "Magic Johnson", "Larry Bird", "Kareem Abdul-Jabbar", "Serena Williams", "Venus Williams",
        "Roger Federer", "Rafael Nadal", "Novak Djokovic", "Usain Bolt", "Michael Phelps",
        "Muhammad Ali", "Mike Tyson", "Floyd Mayweather", "Cristiano Ronaldo", "Lionel Messi",
        "Pelé", "Diego Maradona", "David Beckham", "Neymar", "Kylian Mbappé",
        "Zinedine Zidane", "Ronaldinho", "Thierry Henry", "Tiger Woods", "Babe Ruth",
        "Tom Brady", "Peyton Manning", "Wayne Gretzky", "Simone Biles", "Nadia Comăneci",
        "Katie Ledecky", "Jesse Owens", "Carl Lewis", "Jackie Robinson", "Lewis Hamilton",
        "Michael Schumacher", "Ayrton Senna", "Yao Ming", "Shaun White", "Tony Hawk",
        "Conor McGregor", "Ronda Rousey", "Hulk Hogan", "John Cena", "The Undertaker",
        "Megan Rapinoe", "Mia Hamm", "Billie Jean King", "Maria Sharapova", "Naomi Osaka",

        // MARK: Science, invention, exploration
        "Albert Einstein", "Isaac Newton", "Marie Curie", "Stephen Hawking", "Charles Darwin",
        "Galileo Galilei", "Nikola Tesla", "Thomas Edison", "Alexander Graham Bell", "Alan Turing",
        "Louis Pasteur", "Sigmund Freud", "Archimedes", "Aristotle", "Plato",
        "Socrates", "Pythagoras", "Nicolaus Copernicus", "Johannes Kepler", "Gregor Mendel",
        "Jane Goodall", "Neil Armstrong", "Buzz Aldrin", "Yuri Gagarin", "Carl Sagan",
        "Neil deGrasse Tyson", "Ada Lovelace", "Rosalind Franklin", "Alfred Nobel", "Benjamin Franklin",
        "The Wright Brothers", "Florence Nightingale", "Hippocrates", "Jacques Cousteau", "Sir Edmund Hillary",

        // MARK: Business & tech
        "Elon Musk", "Steve Jobs", "Bill Gates", "Warren Buffett", "Mark Zuckerberg",
        "Jeff Bezos", "Henry Ford", "John D. Rockefeller", "Coco Chanel", "Ralph Lauren",

        // MARK: History & politics
        "Abraham Lincoln", "George Washington", "Napoleon Bonaparte", "Julius Caesar", "Cleopatra",
        "Alexander the Great", "Genghis Khan", "Joan of Arc", "Christopher Columbus", "Marco Polo",
        "Winston Churchill", "Franklin D. Roosevelt", "John F. Kennedy", "Martin Luther King Jr.", "Nelson Mandela",
        "Mahatma Gandhi", "Mother Teresa", "Rosa Parks", "Malcolm X", "Anne Frank",
        "Queen Elizabeth II", "Queen Victoria", "Henry VIII", "Marie Antoinette", "Catherine the Great",
        "Tutankhamun", "Confucius", "Thomas Jefferson", "Theodore Roosevelt", "Barack Obama",
        "Amelia Earhart", "Harriet Tubman", "Susan B. Anthony", "Ferdinand Magellan", "Helen Keller",
        "Che Guevara", "Karl Marx", "Blackbeard", "Attila the Hun", "Paul Revere",

        // MARK: Art & letters
        "Leonardo da Vinci", "Michelangelo", "Rembrandt", "Vincent van Gogh", "Pablo Picasso",
        "Salvador Dalí", "Claude Monet", "Andy Warhol", "Frida Kahlo", "Banksy",
        "William Shakespeare", "Charles Dickens", "Jane Austen", "Mark Twain", "Ernest Hemingway",
        "J.K. Rowling", "Stephen King", "Agatha Christie", "Edgar Allan Poe", "Leo Tolstoy",
        "J.R.R. Tolkien", "George Orwell", "Roald Dahl", "Dr. Seuss", "Hans Christian Andersen",
        "The Brothers Grimm", "Homer", "Victor Hugo", "Jules Verne", "Maya Angelou",
        "Wolfgang Amadeus Mozart", "Ludwig van Beethoven", "Johann Sebastian Bach", "Frédéric Chopin", "Tchaikovsky",

        // MARK: Characters — books & film
        "Harry Potter", "Hermione Granger", "Ron Weasley", "Albus Dumbledore", "Lord Voldemort",
        "Hagrid", "Severus Snape", "Sherlock Holmes", "Doctor Watson", "James Bond",
        "Gandalf", "Frodo Baggins", "Bilbo Baggins", "Gollum", "Aragorn",
        "Legolas", "Jack Sparrow", "Indiana Jones", "Forrest Gump", "Willy Wonka",
        "Robin Hood", "Peter Pan", "Tinker Bell", "Captain Hook", "Dracula",
        "Frankenstein's Monster", "Tarzan", "Robinson Crusoe", "Don Quixote", "Pinocchio",
        "The Little Prince", "Alice", "The Mad Hatter", "The Cheshire Cat", "Dorothy Gale",
        "The Scarecrow", "The Tin Man", "The Cowardly Lion", "Katniss Everdeen", "Hannibal Lecter",
        "Rocky Balboa", "The Terminator", "John Wick", "Neo", "Darth Vader",
        "Luke Skywalker", "Princess Leia", "Han Solo", "Yoda", "Chewbacca",
        "R2-D2", "C-3PO", "Obi-Wan Kenobi", "Marty McFly", "E.T.",
        "Godzilla", "King Kong", "Freddy Krueger", "Mary Poppins", "Ebenezer Scrooge",
        "Oliver Twist", "Huckleberry Finn", "Tom Sawyer", "Captain Ahab", "Romeo",
        "Juliet", "Hamlet", "Macbeth", "Long John Silver", "Rip Van Winkle",

        // MARK: Characters — superheroes & villains
        "Batman", "Superman", "Spider-Man", "Iron Man", "Wonder Woman",
        "Captain America", "The Hulk", "Thor", "Black Widow", "Hawkeye",
        "Black Panther", "Doctor Strange", "Aquaman", "The Flash", "Green Lantern",
        "Wolverine", "Deadpool", "Professor X", "Magneto", "Storm",
        "The Joker", "Harley Quinn", "Catwoman", "The Riddler", "Thanos",
        "Loki", "Lex Luthor", "Green Goblin", "Venom", "Groot",
        "Rocket Raccoon", "Star-Lord", "Ant-Man", "Robin", "Supergirl",

        // MARK: Characters — cartoons
        "Mickey Mouse", "Minnie Mouse", "Donald Duck", "Goofy", "Pluto",
        "Bugs Bunny", "Daffy Duck", "Porky Pig", "Tweety", "Sylvester",
        "Road Runner", "Wile E. Coyote", "Tom and Jerry", "Scooby-Doo", "Shaggy",
        "Popeye", "Betty Boop", "Woody Woodpecker", "Homer Simpson", "Bart Simpson",
        "Lisa Simpson", "Marge Simpson", "Ned Flanders", "Peter Griffin", "Stewie Griffin",
        "Eric Cartman", "SpongeBob SquarePants", "Patrick Star", "Squidward", "Mr. Krabs",
        "Charlie Brown", "Snoopy", "Garfield", "Winnie the Pooh", "Tigger",
        "Eeyore", "Piglet", "Shrek", "Donkey", "Princess Fiona",
        "Puss in Boots", "Buzz Lightyear", "Woody", "Nemo", "Dory",
        "Simba", "Mufasa", "Scar", "Timon", "Pumbaa",
        "Elsa", "Anna", "Olaf", "Cinderella", "Snow White",
        "Sleeping Beauty", "Ariel", "Belle", "Jasmine", "Aladdin",
        "Genie", "Mulan", "Moana", "Rapunzel", "Pocahontas",
        "Bambi", "Dumbo", "Naruto", "Goku", "Astro Boy",
        "Doraemon", "Totoro", "Hello Kitty",

        // MARK: Characters — games, toys, holidays
        "Mario", "Luigi", "Princess Peach", "Bowser", "Yoshi",
        "Donkey Kong", "Link", "Zelda", "Sonic the Hedgehog", "Pikachu",
        "Kirby", "Pac-Man", "Lara Croft", "Master Chief", "Kratos",
        "Barbie", "Ken", "Santa Claus", "The Easter Bunny", "The Tooth Fairy",
        "Frosty the Snowman", "Rudolph the Red-Nosed Reindeer", "The Grinch", "The Cat in the Hat", "Humpty Dumpty",
        "Goldilocks", "Little Red Riding Hood", "The Big Bad Wolf", "Jack Frost", "The Sandman",
    ]
}
