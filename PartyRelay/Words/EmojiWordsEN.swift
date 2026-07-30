import Foundation

// Emoji Manager (English): titles, names, things and sayings you can spell out in emoji
// Picked for "breaks into a few concrete images" — abstract phrases don't work here
enum EmojiWordsEN {

    static let tier1: [String] = [
        // Movies & animation everybody knows
        "The Lion King", "Frozen", "Toy Story", "Finding Nemo", "Snow White",
        "Cinderella", "The Little Mermaid", "Sleeping Beauty", "Peter Pan", "Shrek",
        "Kung Fu Panda", "Ice Age", "Minions", "Zootopia", "Cars",
        "Spider-Man", "Batman", "Superman", "Iron Man", "Titanic",
        "Aladdin", "Mulan", "Moana", "Tangled", "Bambi",
        "Dumbo", "Pinocchio", "101 Dalmatians", "The Jungle Book", "Madagascar",
        "Happy Feet", "Rio", "Bolt", "Brave", "Hercules",
        "Tarzan", "Pocahontas", "Big Hero 6", "Wreck-It Ralph", "Alice in Wonderland",
        "The Croods", "Trolls", "Sing", "Turning Red", "Luca",
        "Soul", "Cruella", "Maleficent", "The Grinch", "Home Alone",

        // Cartoons, characters & games
        "SpongeBob", "Tom and Jerry", "Mickey Mouse", "Pikachu", "Santa Claus",
        "Winnie the Pooh", "Scooby-Doo", "Bugs Bunny", "Popeye", "Garfield",
        "Snoopy", "The Simpsons", "Hello Kitty", "Barbie", "Mario",
        "Sonic the Hedgehog", "Donkey Kong", "Pac-Man", "Angry Birds", "Minecraft",
        "Doraemon", "Astro Boy", "Godzilla", "King Kong", "Frosty the Snowman",

        // Fairy tales & fables
        "The Three Little Pigs", "Little Red Riding Hood", "The Ugly Duckling",
        "The Tortoise and the Hare", "Goldilocks and the Three Bears", "Jack and the Beanstalk",
        "Hansel and Gretel", "The Boy Who Cried Wolf", "The Emperor's New Clothes",
        "Thumbelina", "Humpty Dumpty", "The Gingerbread Man", "Puss in Boots",
        "The Princess and the Pea", "The Ant and the Grasshopper",

        // Everyday sayings
        "raining cats and dogs", "piece of cake", "cold feet", "couch potato", "night owl",
        "break the ice", "when pigs fly", "time flies", "over the moon", "hot dog",
        "bookworm", "copycat", "eagle eye", "busy as a bee", "in hot water",
        "under the weather", "head in the clouds", "green thumb", "sweet tooth", "cat nap",
        "big fish", "top dog", "black sheep", "early bird", "heart of gold",
        "rain check", "small potatoes", "hot potato", "snail mail", "lovebirds",
        "fish out of water", "on cloud nine", "a rolling stone", "sitting duck", "cash cow",

        // Food
        "pizza", "hamburger", "french fries", "sushi", "tacos",
        "spaghetti", "pancakes", "popcorn", "ice cream", "birthday cake",
        "donut", "cupcake", "watermelon", "pineapple", "strawberry",
        "peanut butter and jelly", "fish and chips", "chicken soup", "apple pie", "hot chocolate",
        "coffee", "milkshake", "bacon and eggs", "grilled cheese", "corn on the cob",

        // Animals & nature
        "panda", "giraffe", "penguin", "butterfly", "octopus",
        "unicorn", "dinosaur", "hedgehog", "rainbow", "volcano",
        "snowman", "thunderstorm", "sunflower", "shooting star", "desert island",

        // Holidays & everyday life
        "Christmas", "Halloween", "Thanksgiving", "New Year's Eve", "Valentine's Day",
        "birthday party", "road trip", "camping", "going to the movies", "grocery shopping",
        "working out", "walking the dog", "doing laundry", "traffic jam", "beach vacation",
    ]

    static let tier2: [String] = [
        // Movies
        "Star Wars", "Jurassic Park", "Pirates of the Caribbean", "The Avengers", "Harry Potter",
        "The Lord of the Rings", "Avatar", "Back to the Future", "The Matrix", "Jaws",
        "Ghostbusters", "Men in Black", "The Wizard of Oz", "Beauty and the Beast", "Up",
        "Ratatouille", "Monsters, Inc.", "Inside Out", "Coco", "Encanto",
        "The Incredibles", "Wall-E", "Despicable Me", "The Karate Kid", "Rocky",
        "Top Gun", "Indiana Jones", "The Mummy", "Mission: Impossible", "Mad Max",
        "The Hunger Games", "Twilight", "The Terminator", "Alien", "E.T.",
        "Gremlins", "Jumanji", "Night at the Museum", "The Princess Bride", "Forrest Gump",
        "The Sixth Sense", "Cast Away", "The Martian", "Gravity", "Free Willy",
        "Life of Pi", "The Revenant", "Black Panther", "Wonder Woman", "Dune",

        // TV
        "Friends", "Stranger Things", "Game of Thrones", "Breaking Bad", "The Office",
        "Sherlock", "Family Guy", "Squid Game", "Black Mirror", "The Walking Dead",
        "Doctor Who", "The Crown", "Downton Abbey", "The Mandalorian", "Wednesday",
        "Money Heist", "Peaky Blinders", "The Big Bang Theory", "How I Met Your Mother", "Grey's Anatomy",
        "Lost", "Prison Break", "Westworld", "Ted Lasso", "The Bear",
        "South Park", "Rick and Morty", "Bridgerton", "Better Call Saul", "Severance",

        // Sayings
        "kill two birds with one stone", "spill the beans", "the elephant in the room",
        "once in a blue moon", "hold your horses", "on thin ice",
        "a wolf in sheep's clothing", "the early bird gets the worm",
        "money doesn't grow on trees", "an apple a day keeps the doctor away",
        "break a leg", "bite off more than you can chew", "cost an arm and a leg",
        "the tip of the iceberg", "a blessing in disguise", "back to square one",
        "cut corners", "add fuel to the fire", "beat around the bush",
        "hit the nail on the head", "a taste of your own medicine",
        "put all your eggs in one basket", "throw in the towel", "right under your nose",
        "pull someone's leg", "see eye to eye", "a storm in a teacup",
        "as cool as a cucumber", "raining on your parade", "the grass is always greener",
        "curiosity killed the cat", "every cloud has a silver lining",
        "actions speak louder than words", "birds of a feather flock together",
        "you can't judge a book by its cover", "when in Rome",
        "the calm before the storm", "a chip on your shoulder",
        "a needle in a haystack", "the ball is in motion",

        // Landmarks & places
        "the Eiffel Tower", "the Statue of Liberty", "the Great Wall of China", "the Pyramids",
        "the Leaning Tower of Pisa", "Big Ben", "the Colosseum", "Mount Everest", "the Grand Canyon",
        "Niagara Falls", "Stonehenge", "the Golden Gate Bridge", "Times Square", "Disneyland",
        "the Sydney Opera House", "the Taj Mahal", "Hollywood", "Las Vegas", "Venice",
        "the Amazon rainforest", "the Sahara Desert", "the North Pole", "Route 66", "the Bermuda Triangle",
        "Area 51",

        // Jobs, sport & modern life
        "firefighter", "astronaut", "police officer", "chef", "doctor",
        "teacher", "lifeguard", "farmer", "pilot", "photographer",
        "detective", "lawyer", "dentist", "mail carrier", "DJ",
        "the Super Bowl", "the World Cup", "the Olympics", "the Tour de France", "a marathon",
        "skydiving", "bungee jumping", "surfing", "skiing", "scuba diving",
        "rock climbing", "karaoke", "escape room", "online shopping", "food delivery",
        "binge-watching", "video call", "taking a selfie", "going viral", "doomscrolling",
    ]

    static let tier3: [String] = [
        // Trickier films
        "The Godfather", "The Shawshank Redemption", "The Silence of the Lambs", "Pulp Fiction",
        "Fight Club", "Inception", "Interstellar", "The Truman Show", "Groundhog Day",
        "Slumdog Millionaire", "The Devil Wears Prada", "Eternal Sunshine of the Spotless Mind",
        "Dead Poets Society", "La La Land", "Bohemian Rhapsody", "Mamma Mia!",
        "The Sound of Music", "Gone with the Wind", "Citizen Kane", "Casablanca",
        "Schindler's List", "Saving Private Ryan", "12 Angry Men",
        "One Flew Over the Cuckoo's Nest", "A Clockwork Orange", "Apocalypse Now",
        "Taxi Driver", "Whiplash", "Parasite", "Get Out",
        "No Country for Old Men", "There Will Be Blood", "The Grand Budapest Hotel",
        "Everything Everywhere All at Once", "Knives Out", "The Wolf of Wall Street",
        "Catch Me If You Can", "The Green Mile", "Rain Man", "Good Will Hunting",

        // Books, anime & long-form
        "The Da Vinci Code", "Sherlock Holmes", "Robinson Crusoe",
        "Around the World in 80 Days", "Your Name", "Attack on Titan", "Death Note",
        "Dragon Ball", "One Piece", "Naruto", "Spirited Away", "My Neighbor Totoro",
        "Princess Mononoke", "Demon Slayer", "Fullmetal Alchemist", "Cowboy Bebop",
        "Moby Dick", "Treasure Island", "The Old Man and the Sea", "Pride and Prejudice",
        "Romeo and Juliet", "A Christmas Carol", "Oliver Twist", "The Great Gatsby",
        "To Kill a Mockingbird", "Lord of the Flies", "Animal Farm", "Nineteen Eighty-Four",
        "The Catcher in the Rye", "War and Peace", "Don Quixote", "The Odyssey",
        "Frankenstein", "Dracula", "Twenty Thousand Leagues Under the Sea",

        // Songs
        "Let It Be", "Yesterday", "Imagine", "Purple Rain", "Thriller",
        "Billie Jean", "Sweet Child o' Mine", "Stairway to Heaven", "Hotel California",
        "Bridge Over Troubled Water", "Rolling in the Deep", "Shake It Off", "Uptown Funk",
        "Old Town Road", "Blinding Lights", "Rocket Man", "Yellow Submarine",
        "Dancing Queen", "I Will Survive", "Singin' in the Rain",

        // Names
        "Albert Einstein", "Isaac Newton", "Cleopatra", "Napoleon", "Shakespeare",
        "Marie Curie", "Elvis Presley", "Michael Jackson", "Leonardo da Vinci", "Beethoven",
        "Mozart", "Vincent van Gogh", "Pablo Picasso", "Charlie Chaplin", "Abraham Lincoln",
        "Christopher Columbus", "Joan of Arc", "Julius Caesar", "Amelia Earhart", "Neil Armstrong",
        "Benjamin Franklin", "Thomas Edison", "Nikola Tesla", "Florence Nightingale", "Mother Teresa",
        "Muhammad Ali", "Marilyn Monroe", "Audrey Hepburn", "Bob Marley", "Freddie Mercury",

        // Harder sayings & proverbs
        "burning the midnight oil", "walking on eggshells", "the ball is in your court",
        "don't cry over spilled milk", "a picture is worth a thousand words",
        "bite the bullet", "let the cat out of the bag", "barking up the wrong tree",
        "when it rains it pours", "the last straw", "a penny for your thoughts",
        "close but no cigar", "caught red-handed",
        "cross that bridge when you come to it",
        "don't count your chickens before they hatch", "go the extra mile",
        "hit the sack", "jump on the bandwagon", "kick the bucket",
        "let sleeping dogs lie", "to make a long story short", "miss the boat",
        "no pain no gain", "off the hook", "on the fence", "out of the blue",
        "pull yourself together", "speak of the devil", "steal someone's thunder",
        "take it with a grain of salt", "the best of both worlds",
        "the whole nine yards", "throw caution to the wind", "time is money",
        "two peas in a pod", "a wild goose chase",
        "you can't have your cake and eat it too", "your guess is as good as mine",
        "a leopard can't change its spots", "all bark and no bite", "bury the hatchet",
        "cat got your tongue", "don't put the cart before the horse",
        "fight fire with fire", "a fish rots from the head",
        "give someone the cold shoulder", "in the same boat", "keep your chin up",
        "let the chips fall where they may", "like a moth to a flame", "rock the boat",
        "saved by the bell", "the writing is on the wall",
        "throw someone under the bus", "a diamond in the rough",
    ]
}
