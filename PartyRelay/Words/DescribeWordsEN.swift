import Foundation

// Say & Guess (taboo-style): things easy to describe in English without saying the word itself
enum DescribeWordsEN {

    static let tier1: [String] = [
        "pizza", "birthday cake", "umbrella", "elephant", "giraffe", "doctor",
        "teacher", "firefighter", "basketball", "soccer", "swimming", "dancing",
        "rainbow", "snowman", "beach", "library", "airport", "ice cream",
        "hamburger", "popcorn", "laptop", "headphones", "toothbrush", "backpack",
        "roller coaster", "campfire", "treehouse", "skateboard", "sunglasses", "watermelon",
        "penguin", "dolphin", "kangaroo", "vampire", "superhero", "pirate",
        "robot", "astronaut", "ninja", "mermaid",
    ]

    static let tier2: [String] = [
        "piece of cake", "break a leg", "couch potato", "road trip", "brain freeze",
        "photobomb", "binge-watching", "spring cleaning", "midnight snack", "dad joke",
        "group chat", "selfie stick", "escape room", "food truck", "garage sale",
        "happy hour", "jet lag", "karaoke night", "lemonade stand", "movie marathon",
        "road rage", "secret handshake", "slam dunk", "snow day", "spoiler alert",
        "surprise party", "talent show", "time capsule", "trick or treat", "tug of war",
        "white lie", "wild goose chase", "sweet tooth", "cold feet", "curveball",
        "elephant in the room", "food coma", "early bird", "night owl", "bucket list",
    ]

    static let tier3: [String] = [
        "Albert Einstein", "Sherlock Holmes", "Harry Potter", "Darth Vader", "Cinderella",
        "Batman", "Spider-Man", "the Mona Lisa", "William Shakespeare", "Leonardo da Vinci",
        "Isaac Newton", "Cleopatra", "Santa Claus", "the Tooth Fairy", "Bigfoot",
        "the Loch Ness Monster", "once in a blue moon", "the ball is in your court",
        "beat around the bush", "bite the bullet", "spill the beans", "under the weather",
        "hit the hay", "burn the midnight oil", "cost an arm and a leg", "the last straw",
        "let the cat out of the bag", "raining cats and dogs", "barking up the wrong tree",
        "a blessing in disguise", "the tip of the iceberg", "throw in the towel",
        "walk on eggshells", "devil's advocate", "the whole nine yards",
        "jump on the bandwagon", "cut to the chase", "go the extra mile",
        "on cloud nine", "up in the air",
    ]
}
