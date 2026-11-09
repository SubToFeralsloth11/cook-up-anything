class_name DB
extends RefCounted
## All food knowledge: ingredients, transformation rules, named recipes,
## dish naming, quality scoring and recipe-step text.
##
## Food data is a Dictionary. A leaf ingredient looks like:
##   {id, cut, washed, cook, cooked, burnt, pm, prog, br, ch, flavor?}
## A combined food is {id:"mix", parts:[leaves...], how:method}.

# id: [name, category, shape, outer hex, inner hex, size, flags, cooked hex?]
# flags: d=needs washing  x=can't be cut  r=unsafe raw  n=finished food
#        l=liquid  s=seasoning  i=made in the kitchen (not in the pantry)
const ING := {
	# --- Produce ---
	"tomato": ["Tomato", "veg", "round", "e8352b", "f25c45", 0.085, "d"],
	"onion": ["Onion", "veg", "round", "c98a4b", "f3ead9", 0.08, "d"],
	"garlic": ["Garlic", "veg", "garlic", "f1ece0", "f7f3e8", 0.05, "ds"],
	"potato": ["Potato", "veg", "potato", "b88a4e", "f0dca0", 0.09, "d"],
	"carrot": ["Carrot", "veg", "carrot", "f07a1a", "f59a3e", 0.16, "d"],
	"lettuce": ["Lettuce", "veg", "leafy", "7fc94a", "b9e58a", 0.12, "d"],
	"cucumber": ["Cucumber", "veg", "long", "2f7d32", "cfe8a9", 0.18, "d"],
	"bell_pepper": ["Bell Pepper", "veg", "pepper", "e53935", "f26b5b", 0.09, "d"],
	"chili": ["Chili", "veg", "chili", "d32f2f", "e85a4f", 0.09, "ds"],
	"mushroom": ["Mushroom", "veg", "mushroom", "c8b49a", "efe5d6", 0.07, "d"],
	"broccoli": ["Broccoli", "veg", "broccoli", "3f8f3a", "7bbf5a", 0.1, "d"],
	"spinach": ["Spinach", "veg", "leafy", "2e7d32", "4caf50", 0.1, "d"],
	"cabbage": ["Cabbage", "veg", "leafy", "a5d6a7", "dcedc8", 0.13, "d"],
	"corn": ["Corn", "veg", "corn", "f5c518", "f7d64a", 0.16, "d"],
	"zucchini": ["Zucchini", "veg", "long", "4b8b3b", "e6edb5", 0.17, "d"],
	"eggplant": ["Eggplant", "veg", "eggplant", "4a2a5c", "ece3c8", 0.15, "d"],
	"pumpkin": ["Pumpkin", "veg", "pumpkin", "f57c00", "ffa040", 0.14, "d"],
	"scallion": ["Scallion", "veg", "scallion", "66bb6a", "f1f8e9", 0.18, "ds"],
	"ginger": ["Ginger", "veg", "potato", "c9a36a", "f3df9c", 0.06, "ds"],
	"basil": ["Basil", "veg", "herb", "2e8b3a", "3fa34d", 0.06, "ds"],
	"avocado": ["Avocado", "fruit", "avocado", "3b5323", "c5e17a", 0.08, "d"],
	"lemon": ["Lemon", "fruit", "lemon", "f9e04b", "fff59d", 0.07, "ds"],
	"lime": ["Lime", "fruit", "lemon", "7cb342", "c5e1a5", 0.06, "ds"],
	"apple": ["Apple", "fruit", "round", "c62828", "fff3c4", 0.08, "d"],
	"banana": ["Banana", "fruit", "banana", "f7d348", "fff4c2", 0.18, ""],
	"strawberry": ["Strawberry", "fruit", "strawberry", "e53935", "f48a8a", 0.05, "d"],
	"blueberry": ["Blueberries", "fruit", "berries", "3949ab", "5c6bc0", 0.05, "dx"],
	"orange": ["Orange", "fruit", "round", "fb8c00", "ffb74d", 0.085, "d"],
	"pineapple": ["Pineapple", "fruit", "pineapple", "e0b23a", "f7e27a", 0.2, "d"],
	"mango": ["Mango", "fruit", "mango", "f9a825", "ffc947", 0.09, "d"],
	# --- Meat, fish & protein ---
	"chicken": ["Chicken", "meat", "drumstick", "f2c9b8", "f5d5c8", 0.12, "r", "d99a4e"],
	"beef": ["Steak", "meat", "steak", "b0303a", "c2414b", 0.13, "r", "6d3b22"],
	"ground_beef": ["Ground Beef", "meat", "mince", "c0424a", "cc5a60", 0.1, "r", "6b4226"],
	"bacon": ["Bacon", "meat", "bacon", "e57373", "f8bbd0", 0.12, "r", "a0402a"],
	"sausage": ["Sausage", "meat", "sausage", "d98880", "e6a29a", 0.13, "r", "8d4a25"],
	"ham": ["Ham", "meat", "ham", "f4a7b0", "f8c3c9", 0.11, ""],
	"pepperoni": ["Pepperoni", "meat", "disc", "b33a2e", "c94a3b", 0.07, ""],
	"salmon": ["Salmon", "fish", "fillet", "fa8c6a", "ffab91", 0.13, "r", "e8a27a"],
	"white_fish": ["White Fish", "fish", "fillet", "eceff1", "fafafa", 0.13, "r", "e0b070"],
	"shrimp": ["Shrimp", "fish", "shrimp", "c9b8b0", "e0d0c8", 0.06, "r", "ff8a65"],
	"tofu": ["Tofu", "protein", "box", "f5f0e0", "fbf8ee", 0.07, ""],
	# --- Dairy & eggs ---
	"egg": ["Egg", "dairy", "egg", "f3e1c4", "ffd54f", 0.06, ""],
	"milk": ["Milk", "dairy", "carton", "ffffff", "f5f5f5", 0.12, "xl"],
	"butter": ["Butter", "dairy", "box", "fff176", "fff59d", 0.05, ""],
	"cheese": ["Cheese", "dairy", "wedge", "ffca28", "ffd54f", 0.08, ""],
	"mozzarella": ["Mozzarella", "dairy", "round", "fafafa", "ffffff", 0.07, ""],
	"parmesan": ["Parmesan", "dairy", "wedge", "f0d68a", "f5e3a8", 0.07, ""],
	"cream": ["Cream", "dairy", "carton", "fff8e1", "fffde7", 0.11, "xl"],
	"yogurt": ["Yogurt", "dairy", "tub", "fffdf5", "ffffff", 0.08, "xl"],
	"ice_cream": ["Ice Cream", "dairy", "tub", "f8bbd0", "fce4ec", 0.09, "x"],
	# --- Grains & bakery ---
	"flour": ["Flour", "grain", "sack", "f5f0e6", "ffffff", 0.1, "x"],
	"sugar": ["Sugar", "grain", "sack", "ffffff", "ffffff", 0.09, "x"],
	"rice": ["Rice", "grain", "sack", "f2efe6", "fafafa", 0.1, "x"],
	"pasta": ["Spaghetti", "grain", "pasta", "f3d27a", "f3d27a", 0.16, "x"],
	"noodles": ["Noodles", "grain", "noodles", "f5dfa0", "f5dfa0", 0.1, "x"],
	"bread": ["Bread", "grain", "loaf", "d9a05b", "f5e1b5", 0.15, ""],
	"bun": ["Burger Bun", "grain", "bun", "e0a050", "f5e1b5", 0.08, ""],
	"tortilla": ["Tortilla", "grain", "tortilla", "f3dfb0", "f3dfb0", 0.12, ""],
	"oats": ["Oats", "grain", "sack", "e8d5a8", "e8d5a8", 0.09, "x"],
	"breadcrumbs": ["Breadcrumbs", "grain", "sack", "e0b060", "e0b060", 0.08, "x"],
	"nori": ["Nori", "grain", "sheet", "1b3a1b", "1b3a1b", 0.1, "x"],
	"chickpeas": ["Chickpeas", "grain", "can", "e8c88a", "e8c88a", 0.08, "x"],
	"beans": ["Beans", "grain", "can", "b5462f", "b5462f", 0.08, "x"],
	# --- Sauces & spices ---
	"salt": ["Salt", "spice", "shaker", "ffffff", "ffffff", 0.06, "xs"],
	"black_pepper": ["Black Pepper", "spice", "shaker", "3e3e3e", "3e3e3e", 0.06, "xs"],
	"herbs": ["Mixed Herbs", "spice", "herb", "558b2f", "689f38", 0.06, "xs"],
	"curry_powder": ["Curry Powder", "spice", "jar", "e6a817", "e6a817", 0.06, "xs"],
	"cinnamon": ["Cinnamon", "spice", "jar", "8d5524", "8d5524", 0.06, "xs"],
	"vanilla": ["Vanilla", "spice", "bottle", "5d4037", "5d4037", 0.06, "xs"],
	"oil": ["Oil", "sauce", "bottle", "e8c547", "e8c547", 0.12, "xl"],
	"soy_sauce": ["Soy Sauce", "sauce", "bottle", "3e2723", "3e2723", 0.11, "xls"],
	"honey": ["Honey", "sauce", "jar", "f9a825", "f9a825", 0.07, "xl"],
	"ketchup": ["Ketchup", "sauce", "bottle", "d32f2f", "d32f2f", 0.11, "xls"],
	"mustard": ["Mustard", "sauce", "bottle", "fbc02d", "fbc02d", 0.11, "xls"],
	"broth": ["Broth", "sauce", "carton", "d7a86e", "d7a86e", 0.12, "xl"],
	"coconut_milk": ["Coconut Milk", "sauce", "can", "f5f5f5", "fafafa", 0.08, "xl"],
	"peanut_butter": ["Peanut Butter", "sauce", "jar", "b07a3a", "b07a3a", 0.07, "x"],
	# --- Sweets ---
	"chocolate": ["Chocolate", "sweet", "bar", "5d3a1a", "6d4423", 0.08, ""],
	"maple_syrup": ["Maple Syrup", "sweet", "bottle", "b5651d", "b5651d", 0.1, "xl"],
	"jam": ["Jam", "sweet", "jar", "b71c4a", "b71c4a", 0.07, "x"],
	"sprinkles": ["Sprinkles", "sweet", "jar", "ff80ab", "ff80ab", 0.06, "x"],
	"marshmallow": ["Marshmallows", "sweet", "marsh", "fafafa", "fafafa", 0.05, "x", "d9a066"],
	# --- Made in the kitchen ---
	"beaten_egg": ["Beaten Egg", "made", "bowl", "ffd54f", "ffd54f", 0.08, "ixl"],
	"fried_egg": ["Fried Egg", "made", "friedegg", "ffffff", "ffc107", 0.08, "inx"],
	"boiled_egg": ["Boiled Egg", "made", "egg", "f5f5f5", "ffd54f", 0.06, "in"],
	"scrambled_eggs": ["Scrambled Eggs", "made", "mound", "ffe082", "ffe082", 0.08, "inx"],
	"batter": ["Batter", "made", "bowl", "f3e5ab", "f3e5ab", 0.08, "irxl"],
	"cake_batter": ["Cake Batter", "made", "bowl", "f8e1a8", "f8e1a8", 0.08, "irxl"],
	"cookie_dough": ["Cookie Dough", "made", "dough", "d9b779", "d9b779", 0.08, "ix"],
	"dough": ["Dough", "made", "dough", "f3e3c0", "f3e3c0", 0.09, "ir"],
	"patty": ["Patty", "made", "patty", "c0424a", "c0424a", 0.08, "irx", "6b3a22"],
	"meatballs": ["Meatballs", "made", "balls", "c0424a", "c0424a", 0.07, "irx", "7a4228"],
	"whipped_cream": ["Whipped Cream", "made", "bowlmound", "ffffff", "ffffff", 0.08, "inx"],
	"mayo": ["Mayo", "made", "bowl", "fff3c4", "fff3c4", 0.07, "inxls"],
	"tomato_sauce": ["Tomato Sauce", "made", "bowl", "c62828", "c62828", 0.08, "inxl"],
	"salsa": ["Salsa", "made", "bowlchunks", "e53935", "e53935", 0.08, "inx"],
	"guacamole": ["Guacamole", "made", "bowl", "9ccc65", "9ccc65", 0.08, "inx"],
	"pesto": ["Pesto", "made", "bowl", "4caf50", "4caf50", 0.07, "inxl"],
	"hummus": ["Hummus", "made", "bowl", "e6cc8f", "e6cc8f", 0.08, "inx"],
	"mashed_potato": ["Mashed Potato", "made", "mound", "fff3c0", "fff3c0", 0.09, "inx"],
	"fries": ["Fries", "made", "fries", "f9c74f", "f9c74f", 0.08, "inx"],
	"crisps": ["Crisps", "made", "chips", "f9d56e", "f9d56e", 0.08, "inx"],
	"tortilla_chips": ["Tortilla Chips", "made", "chips", "f4c542", "f4c542", 0.08, "inx"],
	"steamed_rice": ["Steamed Rice", "made", "mound", "fafafa", "fafafa", 0.09, "inx"],
	"cooked_pasta": ["Cooked Spaghetti", "made", "noodlepile", "f5d77a", "f5d77a", 0.09, "inx"],
	"cooked_noodles": ["Cooked Noodles", "made", "noodlepile", "f7e0a0", "f7e0a0", 0.09, "inx"],
	"popcorn": ["Popcorn", "made", "popcorn", "fff8e1", "fff8e1", 0.08, "inx"],
	"caramel": ["Caramel", "made", "bowl", "c47a1d", "c47a1d", 0.07, "inxl"],
	"melted_chocolate": ["Melted Chocolate", "made", "bowl", "4e2c12", "4e2c12", 0.07, "inxl"],
	"toast": ["Toast", "made", "toast", "c98a3e", "f0d9a8", 0.08, "in"],
	"grilled_cheese": ["Grilled Cheese", "made", "sandwich", "d4943c", "ffca28", 0.08, "in"],
	"french_toast": ["French Toast", "made", "toast", "e0a64a", "f5d58a", 0.08, "in"],
	"bread_loaf": ["Fresh Bread", "made", "loaf", "c98a3e", "f5e1b5", 0.14, "in"],
	"pizza": ["Pizza", "made", "pizza", "e8b65a", "d84315", 0.12, "in"],
	"pie": ["Pie", "made", "pie", "d9a050", "b71c1c", 0.11, "in"],
	"cake": ["Cake", "made", "cake", "f8e1c0", "fce4ec", 0.1, "in"],
	"muffins": ["Muffins", "made", "muffins", "d9a050", "8d6e63", 0.08, "inx"],
	"cookies": ["Cookies", "made", "cookies", "c98a3e", "4e342e", 0.08, "inx"],
	"pancakes": ["Pancakes", "made", "stack", "e8b060", "fff59d", 0.09, "in"],
	"donuts": ["Donuts", "made", "donuts", "d99a4e", "f8bbd0", 0.08, "inx"],
	"smoothie": ["Smoothie", "made", "glass", "f48fb1", "f48fb1", 0.08, "inxl"],
	"juice": ["Juice", "made", "glass", "ffb74d", "ffb74d", 0.08, "inxl"],
	"milkshake": ["Milkshake", "made", "glass", "f8bbd0", "f8bbd0", 0.08, "inxl"],
	"lemonade": ["Lemonade", "made", "glass", "fff59d", "fff59d", 0.08, "inxl"],
	"hot_chocolate": ["Hot Chocolate", "made", "mug", "6d4c41", "6d4c41", 0.08, "inxl"],
	"porridge": ["Porridge", "made", "bowl", "e8dcc0", "e8dcc0", 0.08, "inx"],
}

const SHORT := {
	"steamed_rice": "Rice", "cooked_pasta": "Spaghetti", "cooked_noodles": "Noodle",
	"ground_beef": "Beef", "white_fish": "Fish", "bell_pepper": "Pepper",
	"black_pepper": "Peppered", "blueberry": "Blueberry", "marshmallow": "Marshmallow",
	"mashed_potato": "Mash", "scrambled_eggs": "Egg", "fried_egg": "Egg",
	"boiled_egg": "Egg", "beaten_egg": "Egg", "bread_loaf": "Bread", "burger_bun": "Bun",
	"tortilla_chips": "Nacho", "melted_chocolate": "Chocolate", "ice_cream": "Ice Cream",
	"maple_syrup": "Maple", "peanut_butter": "Peanut Butter", "coconut_milk": "Coconut",
	"curry_powder": "Curry", "soy_sauce": "Soy", "tomato_sauce": "Tomato",
	"whipped_cream": "Cream", "cake_batter": "Cake", "cookie_dough": "Cookie Dough",
}

const TABS := [
	["Produce", ["veg", "fruit"]],
	["Meat & Fish", ["meat", "fish", "protein"]],
	["Dairy & Eggs", ["dairy"]],
	["Grains & Bakery", ["grain"]],
	["Sauces & Spices", ["sauce", "spice"]],
	["Sweets", ["sweet"]],
]

const STATION_OF := {"fry": "Pan", "boil": "Pot", "bake": "Oven", "deepfry": "Fryer",
	"mix": "Mixing Bowl", "blend": "Blender"}
const ADJ := {"fry": "Fried", "boil": "Boiled", "bake": "Roasted", "deepfry": "Deep-Fried"}
const BASE_TIME := {"fry": 7.0, "boil": 9.0, "bake": 11.0, "deepfry": 6.0}
const BROWN := {"fry": 0.5, "boil": 0.1, "bake": 0.55, "deepfry": 0.8}
const CAN_BURN := {"fry": true, "bake": true, "deepfry": true, "boil": false}
const TIME_MULT := {"chicken": 1.3, "beef": 1.15, "potato": 1.3, "rice": 1.2, "pumpkin": 1.3,
	"sausage": 1.15, "dough": 1.2, "cake_batter": 1.2, "corn": 1.1, "egg": 0.8, "shrimp": 0.7,
	"bread": 0.6, "toast": 0.6, "marshmallow": 0.5, "sugar": 0.8, "chocolate": 0.6}

const CUT_MAX := {"egg": 1, "bread": 1, "bun": 1, "dough": 1, "boiled_egg": 1, "toast": 1,
	"bread_loaf": 1, "tortilla": 1, "pizza": 1, "cake": 1, "pie": 1, "butter": 1}
const CUT_WORDS := {
	"egg": ["", "Cracked"], "bread": ["", "Sliced"], "bun": ["", "Split"], "dough": ["", "Rolled"],
	"boiled_egg": ["", "Sliced"], "toast": ["", "Cut"], "bread_loaf": ["", "Sliced"],
	"tortilla": ["", "Cut"], "pizza": ["", "Sliced"], "cake": ["", "Sliced"], "pie": ["", "Sliced"],
	"butter": ["", "Sliced"], "cheese": ["", "Sliced", "Grated"], "parmesan": ["", "Shaved", "Grated"],
}
const DEFAULT_CUT_WORDS := ["", "Chopped", "Minced", "Puréed"]
const CUT_VERB := {"Chopped": "chop", "Minced": "mince", "Cracked": "crack", "Sliced": "slice",
	"Rolled": "roll flat", "Split": "split", "Cut": "cut", "Grated": "grate", "Shaved": "shave"}

# [method, input specs, output id, index of input whose name flavours the output (-1 none)]
# Spec grammar: alternatives "a|b" (each may end /c1 = cut at least 1, /w = whole),
# then optional ":fry,bake" (any of these methods), ":cooked" or ":raw".
# "#cat" matches a category, "*" matches any single ingredient.
const RULES := [
	["mix", ["flour", "sugar", "egg/c1", "butter", "milk"], "cake_batter", -1],
	["mix", ["flour", "sugar", "butter", "egg/c1"], "cookie_dough", -1],
	["mix", ["flour", "egg/c1", "milk"], "batter", -1],
	["mix", ["egg/c1", "oil"], "mayo", -1],
	["mix", ["egg/c1"], "beaten_egg", -1],
	["mix", ["flour"], "dough", -1],
	["mix", ["ground_beef", "breadcrumbs|egg/c1"], "meatballs", -1],
	["mix", ["ground_beef"], "patty", -1],
	["mix", ["cream"], "whipped_cream", -1],
	["mix", ["tomato/c1", "onion/c1"], "salsa", -1],
	["mix", ["avocado/c1", "lime|lemon"], "guacamole", -1],
	["mix", ["potato:boil", "butter|milk"], "mashed_potato", -1],
	["blend", ["ice_cream", "milk", "*"], "milkshake", 2],
	["blend", ["ice_cream", "milk"], "milkshake", -1],
	["blend", ["basil", "garlic", "oil"], "pesto", -1],
	["blend", ["avocado", "lime|lemon"], "guacamole", -1],
	["blend", ["lemon", "sugar"], "lemonade", -1],
	["blend", ["#fruit", "milk|yogurt"], "smoothie", 0],
	["blend", ["potato:boil"], "mashed_potato", -1],
	["blend", ["tomato"], "tomato_sauce", -1],
	["blend", ["chickpeas"], "hummus", -1],
	["blend", ["#fruit"], "juice", 0],
	["fry", ["bread/c1", "beaten_egg"], "french_toast", -1],
	["fry", ["bread/c1", "cheese|mozzarella"], "grilled_cheese", -1],
	["fry", ["batter", "#fruit|chocolate"], "pancakes", 1],
	["fry", ["sugar", "butter"], "caramel", -1],
	["fry", ["corn", "butter|oil"], "popcorn", -1],
	["fry", ["egg/c1"], "fried_egg", -1],
	["fry", ["beaten_egg"], "scrambled_eggs", -1],
	["fry", ["batter"], "pancakes", -1],
	["fry", ["bread/c1|bread_loaf/c1"], "toast", -1],
	["fry", ["sugar"], "caramel", -1],
	["fry", ["chocolate"], "melted_chocolate", -1],
	["boil", ["oats", "milk"], "porridge", -1],
	["boil", ["milk", "chocolate"], "hot_chocolate", -1],
	["boil", ["rice"], "steamed_rice", -1],
	["boil", ["pasta"], "cooked_pasta", -1],
	["boil", ["noodles"], "cooked_noodles", -1],
	["boil", ["egg/w"], "boiled_egg", -1],
	["boil", ["oats"], "porridge", -1],
	["boil", ["chocolate"], "melted_chocolate", -1],
	["bake", ["dough", "tomato_sauce", "cheese|mozzarella"], "pizza", -1],
	["bake", ["dough", "#fruit|#meat|#fish|pumpkin|mushroom"], "pie", 1],
	["bake", ["cake_batter", "*"], "cake", 1],
	["bake", ["cookie_dough", "*"], "cookies", 1],
	["bake", ["batter", "#fruit"], "muffins", 1],
	["bake", ["dough", "*"], "bread_loaf", 1],
	["bake", ["dough"], "bread_loaf", -1],
	["bake", ["cake_batter"], "cake", -1],
	["bake", ["cookie_dough"], "cookies", -1],
	["bake", ["batter"], "muffins", -1],
	["bake", ["bread/c1"], "toast", -1],
	["deepfry", ["potato/c2"], "crisps", -1],
	["deepfry", ["potato/c1"], "fries", -1],
	["deepfry", ["tortilla"], "tortilla_chips", -1],
	["deepfry", ["dough"], "donuts", -1],
	["deepfry", ["corn"], "popcorn", -1],
]

# [name, specs]. "{} " in a name is replaced by the flavour of a flavoured leaf.
const RECIPES := [
	# Breakfast
	["Fried Egg on Toast", ["fried_egg", "toast"]],
	["Scrambled Eggs on Toast", ["scrambled_eggs", "toast"]],
	["Bacon & Eggs", ["bacon:fry,bake", "fried_egg|scrambled_eggs"]],
	["Full Breakfast", ["fried_egg|scrambled_eggs", "bacon:cooked", "sausage:cooked", "toast"]],
	["Pancake Stack", ["pancakes", "maple_syrup|honey"]],
	["Pancakes & Cream", ["pancakes", "whipped_cream"]],
	["Chocolate Banana Pancakes", ["pancakes", "banana", "chocolate|melted_chocolate"]],
	["{} Pancakes", ["pancakes"]],
	["French Toast", ["french_toast"]],
	["French Toast & Syrup", ["french_toast", "maple_syrup|honey"]],
	["Porridge", ["porridge"]],
	["Honey Banana Porridge", ["porridge", "banana", "honey"]],
	["Berry Porridge", ["porridge", "strawberry|blueberry"]],
	["Avocado Toast", ["toast", "avocado/c1"]],
	["Cheese Omelette", ["scrambled_eggs", "cheese"]],
	["Ham & Cheese Omelette", ["scrambled_eggs", "ham", "cheese"]],
	["Veggie Omelette", ["scrambled_eggs", "bell_pepper|mushroom|spinach", "onion|tomato|scallion"]],
	["Yogurt Parfait", ["yogurt", "#fruit", "oats"]],
	["Breakfast Burrito", ["tortilla", "scrambled_eggs", "bacon|sausage:cooked", "cheese"]],
	["Egg Sandwich", ["bread/c1|bun|toast", "fried_egg"]],
	["Toast & Jam", ["toast", "jam"]],
	["Peanut Butter & Jelly", ["bread/c1|toast", "peanut_butter", "jam"]],
	["Cinnamon Toast", ["toast", "cinnamon", "sugar|butter|honey"]],
	["Peanut Butter Banana Toast", ["toast", "peanut_butter", "banana"]],
	# Sandwiches & burgers
	["Grilled Cheese", ["grilled_cheese"]],
	["Ham & Cheese Toastie", ["grilled_cheese", "ham"]],
	["BLT", ["bread/c1|toast", "bacon:cooked", "lettuce", "tomato/c1"]],
	["Club Sandwich", ["toast", "chicken:cooked", "bacon:cooked", "lettuce", "tomato/c1"]],
	["Hamburger", ["bun", "patty:fry,bake"]],
	["Cheeseburger", ["bun", "patty:fry,bake", "cheese"]],
	["Bacon Cheeseburger", ["bun", "patty:fry,bake", "bacon:cooked", "cheese"]],
	["Deluxe Burger", ["bun", "patty:fry,bake", "cheese", "lettuce", "tomato/c1", "onion/c1"]],
	["Chicken Burger", ["bun", "chicken:fry,deepfry,bake"]],
	["Fish Burger", ["bun|bread/c1", "white_fish|salmon:cooked"]],
	["Hot Dog", ["bun", "sausage:cooked"]],
	["Loaded Hot Dog", ["bun", "sausage:cooked", "onion/c1", "ketchup|mustard"]],
	["Egg Mayo Sandwich", ["bread/c1|toast", "boiled_egg/c1", "mayo"]],
	["Meatball Sub", ["bun|bread/c1", "meatballs:cooked", "tomato_sauce"]],
	["Ham Sandwich", ["bread/c1", "ham", "butter|mustard|mayo"]],
	# Mexican
	["Beef Tacos", ["tortilla", "ground_beef:fry"]],
	["Chicken Tacos", ["tortilla", "chicken/c1:fry"]],
	["Fish Tacos", ["tortilla", "white_fish:fry,deepfry"]],
	["Burrito", ["tortilla", "steamed_rice", "beans", "ground_beef|chicken:cooked"]],
	["Quesadilla", ["tortilla:fry", "cheese:fry"]],
	["Nachos", ["tortilla_chips", "cheese"]],
	["Loaded Nachos", ["tortilla_chips", "cheese", "salsa", "guacamole"]],
	["Chips & Guac", ["tortilla_chips", "guacamole"]],
	["Chips & Salsa", ["tortilla_chips", "salsa"]],
	["Fajitas", ["tortilla", "chicken/c1|beef/c1:fry", "bell_pepper/c1:fry", "onion/c1:fry"]],
	["Chili con Carne", ["ground_beef:cooked", "beans", "tomato_sauce|tomato/c1", "chili"]],
	# Italian
	["Spaghetti Bolognese", ["cooked_pasta", "tomato_sauce", "ground_beef:cooked"]],
	["Spaghetti & Meatballs", ["cooked_pasta", "meatballs:cooked", "tomato_sauce"]],
	["Pasta Pomodoro", ["cooked_pasta", "tomato_sauce"]],
	["Mac & Cheese", ["cooked_pasta", "cheese", "milk|cream"]],
	["Baked Mac & Cheese", ["cooked_pasta:bake", "cheese:bake", "breadcrumbs"]],
	["Carbonara", ["cooked_pasta", "bacon:cooked", "egg|beaten_egg|scrambled_eggs", "parmesan"]],
	["Pesto Pasta", ["cooked_pasta", "pesto"]],
	["Fettuccine Alfredo", ["cooked_pasta", "cream", "parmesan"]],
	["Garlic Butter Pasta", ["cooked_pasta", "garlic", "butter"]],
	["Lasagna", ["cooked_pasta:bake", "tomato_sauce:bake", "ground_beef:bake", "cheese|mozzarella:bake"]],
	["Cheese Pizza", ["pizza"]],
	["Margherita Pizza", ["pizza", "basil"]],
	["Pepperoni Pizza", ["pizza", "pepperoni"]],
	["Hawaiian Pizza", ["pizza", "ham", "pineapple"]],
	["Meat Lovers Pizza", ["pizza", "pepperoni", "bacon", "sausage"]],
	["Veggie Pizza", ["pizza", "bell_pepper", "mushroom", "onion"]],
	["Caprese Salad", ["tomato/c1", "mozzarella", "basil"]],
	["Bruschetta", ["toast", "tomato/c1", "basil|garlic"]],
	["Garlic Bread", ["toast|bread_loaf", "garlic", "butter"]],
	["Mushroom Risotto", ["steamed_rice", "mushroom:cooked", "parmesan|cheese"]],
	# Asian
	["Egg Fried Rice", ["steamed_rice:fry", "egg|beaten_egg|scrambled_eggs|fried_egg"]],
	["Chicken Fried Rice", ["steamed_rice:fry", "chicken:fry", "scallion|onion|carrot"]],
	["Teriyaki Chicken", ["chicken:fry,bake", "soy_sauce", "honey"]],
	["Teriyaki Rice Bowl", ["steamed_rice", "chicken:cooked", "soy_sauce", "honey"]],
	["Chicken Stir-Fry", ["chicken/c1:fry", "bell_pepper|broccoli|carrot|cabbage:fry", "soy_sauce"]],
	["Beef & Broccoli", ["beef/c1:fry", "broccoli:cooked", "soy_sauce"]],
	["Veggie Stir-Fry", ["#veg:fry", "#veg:fry", "#veg:fry", "soy_sauce"]],
	["Chow Mein", ["cooked_noodles:fry", "cabbage|carrot|bell_pepper:fry", "soy_sauce"]],
	["Pad Thai", ["cooked_noodles:fry", "shrimp|chicken|tofu:fry", "peanut_butter", "egg|beaten_egg|scrambled_eggs"]],
	["Ramen", ["cooked_noodles", "broth", "boiled_egg"]],
	["Chicken Ramen", ["cooked_noodles", "broth", "chicken:cooked"]],
	["Chicken Curry", ["chicken:cooked", "curry_powder"]],
	["Coconut Curry", ["#meat|#fish|tofu:cooked", "curry_powder", "coconut_milk"]],
	["Vegetable Curry", ["#veg:cooked", "#veg:cooked", "curry_powder"]],
	["Salmon Sushi Roll", ["nori", "steamed_rice", "salmon/c1:raw"]],
	["Veggie Sushi Roll", ["nori", "steamed_rice", "cucumber/c1|avocado/c1"]],
	["Sashimi", ["salmon/c1:raw", "soy_sauce"]],
	["Poke Bowl", ["steamed_rice", "salmon/c1:raw", "avocado/c1", "soy_sauce"]],
	["Bibimbap", ["steamed_rice", "fried_egg", "spinach|carrot", "beef|ground_beef:cooked"]],
	["Mapo Tofu", ["tofu:cooked", "ground_beef:cooked", "chili"]],
	["Shrimp Tempura", ["shrimp:deepfry", "batter:deepfry"]],
	["Garlic Butter Shrimp", ["shrimp:fry", "garlic", "butter"]],
	["Sweet & Sour Chicken", ["chicken:deepfry,fry", "pineapple", "ketchup"]],
	["Dumplings", ["dough:boil", "ground_beef|shrimp:boil"]],
	["Potstickers", ["dough:fry", "ground_beef|shrimp:fry"]],
	["Tofu Stir-Fry", ["tofu:fry", "#veg:fry", "soy_sauce"]],
	# Mains
	["Steak & Chips", ["beef:fry,bake", "fries"]],
	["Steak & Mash", ["beef:cooked", "mashed_potato"]],
	["Fish & Chips", ["white_fish:deepfry", "batter:deepfry", "fries"]],
	["Fried Chicken", ["chicken:deepfry", "flour|breadcrumbs|batter"]],
	["Chicken Nuggets", ["chicken/c1:deepfry", "breadcrumbs"]],
	["Roast Chicken", ["chicken:bake"]],
	["Roast Dinner", ["chicken|beef:bake", "potato:bake", "carrot:bake"]],
	["Honey Glazed Salmon", ["salmon:cooked", "honey"]],
	["Lemon Herb Fish", ["white_fish|salmon:cooked", "lemon", "herbs|basil"]],
	["Bangers & Mash", ["sausage:cooked", "mashed_potato"]],
	["Shepherd's Pie", ["ground_beef:bake", "mashed_potato:bake"]],
	["Beef Stew", ["beef:boil", "potato:boil", "carrot:boil"]],
	["Baked Potato", ["potato/w:bake"]],
	["Loaded Baked Potato", ["potato/w:bake", "cheese", "bacon:cooked"]],
	["Ratatouille", ["zucchini:cooked", "eggplant:cooked", "tomato:cooked", "bell_pepper:cooked"]],
	["Stuffed Peppers", ["bell_pepper/w:bake", "steamed_rice|ground_beef"]],
	["Chicken & Rice", ["chicken:cooked", "steamed_rice"]],
	["Crispy Fries", ["fries", "salt"]],
	["Chips & Dip", ["crisps", "salsa|guacamole|hummus|mayo"]],
	# Soups & salads
	["Tomato Soup", ["tomato_sauce:boil"]],
	["Cream of Tomato Soup", ["tomato_sauce:boil", "cream"]],
	["Pumpkin Soup", ["pumpkin/c3:boil"]],
	["Chicken Noodle Soup", ["chicken:boil", "cooked_noodles", "carrot|onion:boil"]],
	["Mushroom Soup", ["mushroom:boil", "cream"]],
	["Corn Chowder", ["corn:boil", "potato:boil", "milk|cream"]],
	["Minestrone", ["cooked_pasta", "tomato|tomato_sauce:boil", "beans"]],
	["Garden Salad", ["lettuce", "tomato/c1", "cucumber/c1"]],
	["Caesar Salad", ["lettuce", "toast", "parmesan"]],
	["Chicken Caesar Salad", ["lettuce", "toast", "parmesan", "chicken:cooked"]],
	["Greek Salad", ["tomato/c1", "cucumber/c1", "onion/c1", "cheese"]],
	["Fruit Salad", ["#fruit/c1", "#fruit/c1", "#fruit/c1"]],
	["Coleslaw", ["cabbage/c1", "carrot/c1", "mayo"]],
	["Potato Salad", ["potato:boil", "mayo"]],
	["Egg Salad", ["boiled_egg/c1", "mayo"]],
	["Hummus & Veggies", ["hummus", "carrot/c1|cucumber/c1|bell_pepper/c1"]],
	# Bakery & desserts
	["{} Pie", ["pie"]],
	["{} Cake", ["cake"]],
	["Birthday Cake", ["cake", "sprinkles|whipped_cream"]],
	["{} Cookies", ["cookies"]],
	["Cookies & Milk", ["cookies", "milk"]],
	["{} Muffins", ["muffins"]],
	["{} Bread", ["bread_loaf"]],
	["Donuts", ["donuts"]],
	["Glazed Donuts", ["donuts", "sugar|sprinkles|melted_chocolate"]],
	["Churros", ["donuts", "cinnamon"]],
	["Banana Split", ["ice_cream", "banana/c1", "chocolate|melted_chocolate|caramel"]],
	["Ice Cream Sundae", ["ice_cream", "melted_chocolate|caramel|chocolate", "sprinkles|whipped_cream"]],
	["Strawberries & Cream", ["strawberry", "whipped_cream|cream"]],
	["Chocolate Strawberries", ["strawberry", "melted_chocolate"]],
	["Popcorn", ["popcorn"]],
	["Caramel Popcorn", ["popcorn", "caramel"]],
	["Apple Crumble", ["apple:bake", "oats:bake", "butter"]],
	["S'mores", ["marshmallow:cooked", "chocolate|melted_chocolate"]],
	["Caramel Apple", ["apple", "caramel"]],
	["Mango Sticky Rice", ["steamed_rice", "mango", "coconut_milk"]],
	["Rice Pudding", ["steamed_rice", "milk:boil", "sugar|cinnamon"]],
	# Drinks
	["{} Smoothie", ["smoothie"]],
	["{} Juice", ["juice"]],
	["{} Milkshake", ["milkshake"]],
	["Lemonade", ["lemonade"]],
	["Pink Lemonade", ["lemonade", "strawberry"]],
	["Hot Chocolate", ["hot_chocolate"]],
	["Hot Chocolate & Marshmallows", ["hot_chocolate", "marshmallow"]],
]

static var _rules: Array = []
static var _recipes: Array = []
static var _how: Dictionary = {}


static func init() -> void:
	if not _rules.is_empty():
		return
	var i := 0
	for r in RULES:
		var specs: Array = []
		for s in r[1]:
			specs.append(parse(s))
		_rules.append({"m": r[0], "specs": specs, "out": r[2], "keep": r[3], "i": i})
		if not _how.has(r[2]) and r[3] < 0:
			_how[r[2]] = r
		i += 1
	for r in RULES:
		if not _how.has(r[2]):
			_how[r[2]] = r
	_rules.sort_custom(func(a, b): return a["specs"].size() > b["specs"].size() \
		or (a["specs"].size() == b["specs"].size() and a["i"] < b["i"]))
	for k in RECIPES.size():
		var r: Array = RECIPES[k]
		var specs: Array = []
		var weight := 0
		for s in r[1]:
			var p := parse(s)
			specs.append(p)
			weight += 10 + int(p["detail"])
		_recipes.append({"name": r[0], "specs": specs, "weight": weight, "id": k})


static func recipe_count() -> int:
	init()
	return _recipes.size()


static func recipe(k: int) -> Dictionary:
	init()
	return _recipes[k]


# ---------------------------------------------------------------- specs

static func parse(s: String) -> Dictionary:
	var sp := {"alts": [], "m": [], "any_cook": false, "raw": false, "detail": 0}
	var halves := s.split(":", true, 1)
	for a in halves[0].split("|"):
		var bits := a.split("/")
		var alt := {"id": "", "cats": [], "any": false, "cut": 0, "whole": false}
		var base: String = bits[0]
		if base == "*":
			alt["any"] = true
		elif base.begins_with("#"):
			var c := base.substr(1)
			alt["cats"] = ["meat", "fish", "protein"] if c == "protein" else [c]
		else:
			alt["id"] = base
			assert(ING.has(base), "Unknown ingredient in spec: " + s)
		if bits.size() > 1:
			if bits[1] == "w":
				alt["whole"] = true
			else:
				alt["cut"] = int(bits[1].substr(1))
			sp["detail"] += 1
		sp["alts"].append(alt)
	if halves.size() > 1:
		sp["detail"] += 1
		match halves[1]:
			"cooked": sp["any_cook"] = true
			"raw": sp["raw"] = true
			_: sp["m"] = Array(halves[1].split(","))
	return sp


static func spec_ok(sp: Dictionary, d: Dictionary) -> bool:
	var id: String = d["id"]
	if id == "mix":
		return false
	var cut: int = d.get("cut", 0)
	var hit := false
	for alt in sp["alts"]:
		if alt["any"] or alt["id"] == id or (alt["cats"] as Array).has(ING[id][1]):
			if alt["whole"] and cut != 0:
				continue
			if cut < int(alt["cut"]):
				continue
			hit = true
			break
	if not hit:
		return false
	var cook: String = d.get("cook", "")
	if sp["raw"]:
		return not d.get("cooked", false)
	if sp["any_cook"]:
		return d.get("cooked", false)
	var ms: Array = sp["m"]
	if ms.is_empty():
		return true
	return d.get("cooked", false) and ms.has(cook)


## Assigns each spec to a distinct candidate. Returns candidate indexes or [].
static func assign(specs: Array, cands: Array) -> Array:
	var used := []
	used.resize(cands.size())
	used.fill(false)
	var out := []
	if _assign(specs, cands, 0, used, out):
		return out
	return []


static func _assign(specs: Array, cands: Array, i: int, used: Array, out: Array) -> bool:
	if i == specs.size():
		return true
	for j in cands.size():
		if used[j] or not spec_ok(specs[i], cands[j]):
			continue
		used[j] = true
		out.append(j)
		if _assign(specs, cands, i + 1, used, out):
			return true
		used[j] = false
		out.pop_back()
	return false


# ---------------------------------------------------------------- data helpers

static func flag(id: String, f: String) -> bool:
	return id != "mix" and String(ING[id][6]).contains(f)


static func new_leaf(id: String) -> Dictionary:
	return {"id": id, "cut": 0, "washed": not flag(id, "d"), "cook": "", "cooked": false,
		"burnt": false, "pm": "", "prog": 0.0, "br": 0.0, "ch": 0.0}


static func leaves(d: Dictionary) -> Array:
	if d["id"] == "mix":
		return d["parts"]
	return [d]


static func merge(items: Array, how: String) -> Dictionary:
	if items.size() == 1:
		return items[0]
	var parts := []
	for d in items:
		parts.append_array(leaves(d))
	return {"id": "mix", "parts": parts, "how": how}


static func cut_max(id: String) -> int:
	if flag(id, "x") or id == "mix":
		return 0
	return CUT_MAX.get(id, 2)


static func cut_word(id: String, cut: int) -> String:
	var words: Array = CUT_WORDS.get(id, DEFAULT_CUT_WORDS)
	if cut >= words.size():
		return DEFAULT_CUT_WORDS[mini(cut, 3)]
	return words[cut]


static func color(hex: String) -> Color:
	return Color(hex)


static func short(id: String) -> String:
	if SHORT.has(id):
		return SHORT[id]
	return ING[id][0]


static func flavor_name(d: Dictionary) -> String:
	if d.has("flavor"):
		return short(d["flavor"])
	return ""


static func cook_time(d: Dictionary, method: String) -> float:
	var t: float = BASE_TIME[method] * TIME_MULT.get(d["id"], 1.0)
	t *= 1.0 - 0.18 * mini(int(d.get("cut", 0)), 2)
	return maxf(t, 2.5)


# ---------------------------------------------------------------- rules

## Applies every matching rule for `method` to top-level food datas.
## Returns {made: new items, rest: untouched items}.
static func apply_rules(method: String, items: Array) -> Dictionary:
	init()
	var pool := items.duplicate()
	var made := []
	for r in _rules:
		if r["m"] != method:
			continue
		while true:
			var asg := assign(r["specs"], pool)
			if asg.is_empty():
				break
			var out := new_leaf(r["out"])
			out["washed"] = true
			if BASE_TIME.has(method):
				out["cook"] = method
				out["cooked"] = true
				out["pm"] = method
				out["prog"] = 1.0
			elif r["out"] in ["mashed_potato", "hot_chocolate", "porridge"]:
				out["cooked"] = true
			var keep: int = r["keep"]
			if keep >= 0:
				var src: Dictionary = pool[asg[keep]]
				out["flavor"] = src["id"]
			var idx := asg.duplicate()
			idx.sort()
			idx.reverse()
			for j in idx:
				pool.remove_at(j)
			made.append(out)
	return {"made": made, "rest": pool}


# ---------------------------------------------------------------- naming

static func leaf_name(d: Dictionary) -> String:
	var id: String = d["id"]
	var nm: String = ING[id][0]
	var fl := flavor_name(d)
	if fl != "":
		nm = fl + " " + nm
	var words := []
	if d.get("burnt", false):
		words.append("Burnt")
	elif d.get("cooked", false) and not flag(id, "n") and d.get("cook", "") != "":
		var adj: String = ADJ[d["cook"]]
		if d["cook"] == "bake" and id in ["bread", "cake_batter", "batter", "dough", "cookie_dough"]:
			adj = "Baked"
		if d["cook"] == "fry" and ING[id][1] == "meat":
			adj = "Seared"
		words.append(adj)
	elif flag(id, "r") and not d.get("cooked", false):
		words.append("Raw")
	var cut: int = d.get("cut", 0)
	if cut > 0:
		words.append(cut_word(id, cut))
	words.append(nm)
	return " ".join(words)


static func food_name(d: Dictionary) -> String:
	if d["id"] != "mix":
		return leaf_name(d)
	return identify(d["parts"])["name"]


static func _priority(d: Dictionary) -> int:
	var id: String = d["id"]
	var cat: String = ING[id][1]
	if flag(id, "s"):
		return 0
	match cat:
		"meat", "fish", "protein": return 6
		"made": return 4 if flag(id, "l") else 5
		"veg", "fruit": return 3
		"grain": return 2
		"dairy": return 2
	return 1


const BASES := {
	"bun": "{} Burger", "bread": "{} Sandwich", "toast": "{} on Toast", "tortilla": "{} Wrap",
	"pizza": "{} Pizza", "cake": "{} Cake", "pancakes": "{} Pancakes", "steamed_rice": "{} Rice Bowl",
	"cooked_pasta": "{} Pasta", "cooked_noodles": "{} Noodles", "ice_cream": "{} Sundae",
	"porridge": "{} Porridge", "nori": "{} Roll", "fries": "{} Loaded Fries",
	"tortilla_chips": "{} Nachos", "mashed_potato": "{} & Mash", "pie": "{} Pie",
	"smoothie": "{} Smoothie", "milkshake": "{} Milkshake", "juice": "{} Juice",
	"yogurt": "{} Yogurt Bowl", "bread_loaf": "{} Loaf", "donuts": "{} Donuts",
}


static func fallback_name(ls: Array) -> String:
	var base_id := ""
	for b in BASES:
		for l in ls:
			if l["id"] == b:
				base_id = b
				break
		if base_id != "":
			break
	var mains := []
	var seen := {}
	var sorted := ls.duplicate()
	sorted.sort_custom(func(a, b): return _priority(a) > _priority(b))
	for l in sorted:
		var id: String = l["id"]
		if id == base_id or seen.has(short(id)):
			continue
		if _priority(l) == 0 and sorted.size() > 1 and _priority(sorted[0]) > 0:
			continue
		seen[short(id)] = true
		mains.append(l)
	var names := []
	for l in mains.slice(0, 2):
		names.append(_nice_short(l))
	var ab := " & ".join(names) if not names.is_empty() else "Mystery"
	var has := func(ids: Array) -> bool:
		for l in ls:
			if ids.has(l["id"]):
				return true
		return false
	var adj := ""
	if has.call(["chili", "curry_powder"]):
		adj = "Spicy "
	elif has.call(["honey", "maple_syrup", "caramel", "sugar"]) and _count_cats(ls, ["meat", "fish"]) > 0:
		adj = "Sticky "
	elif has.call(["cheese", "mozzarella", "parmesan"]) and not ab.contains("Cheese") \
			and not ab.contains("Mozzarella") and not ab.contains("Parmesan"):
		adj = "Cheesy "
	elif has.call(["garlic"]) and not ab.contains("Garlic"):
		adj = "Garlicky "
	if ls.size() >= 7:
		adj = "Ultimate " + adj
	if base_id != "":
		var t: String = BASES[base_id]
		if base_id == "tortilla" and _count_method(ls, "fry") > 0:
			t = "{} Tacos"
		if mains.is_empty():
			return leaf_name(ls[0])
		return adj + t.replace("{}", ab)
	var counts := {}
	var puree := 0
	for l in ls:
		if int(l.get("cut", 0)) >= 3:
			puree += 1
		if l.get("cooked", false) and l.get("cook", "") != "":
			counts[l["cook"]] = counts.get(l["cook"], 0) + 1
	var m := ""
	var best := 0
	for k in counts:
		if counts[k] > best:
			best = counts[k]
			m = k
	var n := mains.size()
	if puree * 2 >= ls.size():
		if _count_cats(ls, ["fruit"]) * 2 >= ls.size():
			return adj + ab + " Smoothie"
		if m == "boil":
			return adj + ab + " Soup"
		return adj + ab + " Purée"
	match m:
		"boil":
			if n >= 3 and _count_cats(ls, ["meat"]) > 0:
				return adj + ab + " Stew"
			return adj + ab + " Soup"
		"fry":
			if n >= 3:
				return adj + ab + " Stir-Fry"
			return adj + "Pan-Fried " + ab
		"deepfry":
			if has.call(["batter"]):
				return adj + ab + " Tempura"
			return adj + "Crispy " + ab
		"bake":
			if n >= 3:
				return adj + ab + " Bake"
			return adj + "Roasted " + ab
	if _count_cats(ls, ["fruit"]) * 2 >= ls.size():
		return adj + ab + " Fruit Salad"
	if _count_cats(ls, ["veg"]) > 0:
		return adj + ab + " Salad"
	if _count_cats(ls, ["sweet"]) > 0:
		return adj + ab + " Treat"
	return adj + ab + " Platter"


static func _nice_short(l: Dictionary) -> String:
	var fl := flavor_name(l)
	var s := short(l["id"])
	if fl != "" and not s.contains(fl):
		return fl + " " + s
	return s


static func _count_cats(ls: Array, cats: Array) -> int:
	var n := 0
	for l in ls:
		if cats.has(ING[l["id"]][1]):
			n += 1
	return n


static func _count_method(ls: Array, m: String) -> int:
	var n := 0
	for l in ls:
		if l.get("cook", "") == m and l.get("cooked", false):
			n += 1
	return n


## Names a set of leaves. Returns {name, recipe (index or -1), extras}.
static func identify(ls: Array) -> Dictionary:
	init()
	if ls.is_empty():
		return {"name": "Empty Plate", "recipe": -1, "extras": []}
	var best := -1
	var best_w := -1
	var best_asg := []
	for r in _recipes:
		var specs: Array = r["specs"]
		if specs.size() > ls.size():
			continue
		var asg := assign(specs, ls)
		if asg.is_empty():
			continue
		var w: int = r["weight"]
		if w > best_w:
			best_w = w
			best = r["id"]
			best_asg = asg
	if best < 0:
		if ls.size() == 1:
			return {"name": leaf_name(ls[0]), "recipe": -1, "extras": []}
		return {"name": fallback_name(ls), "recipe": -1, "extras": []}
	var rec: Dictionary = _recipes[best]
	var nm: String = rec["name"]
	if nm.contains("{} "):
		var fl := ""
		for j in best_asg:
			fl = flavor_name(ls[j])
			if fl != "":
				break
		nm = nm.replace("{} ", (fl + " ") if fl != "" else "")
	var extras := []
	var seen := {}
	for j in ls.size():
		if best_asg.has(j):
			continue
		var l: Dictionary = ls[j]
		if flag(l["id"], "s") or seen.has(l["id"]):
			continue
		seen[l["id"]] = true
		extras.append(_nice_short(l))
	if extras.size() >= 3:
		nm = "Loaded " + nm
	elif not extras.is_empty():
		nm += " with " + " & ".join(extras)
	if _burnt_share(ls) > 0.5:
		nm = "Burnt " + nm
	return {"name": nm, "recipe": best, "extras": extras}


static func _burnt_share(ls: Array) -> float:
	var b := 0
	for l in ls:
		if l.get("burnt", false):
			b += 1
	return float(b) / maxf(1.0, ls.size())


# ---------------------------------------------------------------- quality

## Returns {stars (0.5..5), notes: Array[String], name, recipe}.
static func judge(ls: Array) -> Dictionary:
	var info := identify(ls)
	var q := 3.0
	var notes := []
	var raw := false
	var burnt := false
	var dirty := false
	var perfect := 0
	var seasoned := false
	var kinds := {}
	for l in ls:
		var id: String = l["id"]
		kinds[id] = true
		if flag(id, "s"):
			seasoned = true
		if l.get("burnt", false):
			q -= 1.2
			burnt = true
			continue
		if flag(id, "r") and not l.get("cooked", false):
			var sashimi: bool = ING[id][1] == "fish" and int(l.get("cut", 0)) >= 1 and id == "salmon"
			if not sashimi:
				q -= 1.5
				raw = true
		if flag(id, "d") and not l.get("washed", false):
			q -= 0.4
			dirty = true
		var p: float = l.get("prog", 0.0)
		if l.get("cooked", false) and p >= 1.0 and p < 1.45 and not flag(id, "n"):
			perfect += 1
	if info["recipe"] >= 0:
		q += 1.5
		notes.append("A true classic!")
	elif ls.size() >= 2:
		q += 0.7
		notes.append("Wildly creative!")
	if seasoned:
		q += 0.4
		notes.append("Nicely seasoned")
	if kinds.size() >= 4:
		q += 0.3
		notes.append("Great variety")
	if perfect > 0:
		q += minf(0.5, perfect * 0.2)
		notes.append("Cooked to perfection")
	if raw:
		notes.append("Some of this is still RAW!")
	if burnt:
		notes.append("Tastes like charcoal...")
	if dirty:
		notes.append("Crunchy... is that dirt? Wash your produce!")
	q = clampf(snappedf(q, 0.5), 0.5, 5.0)
	return {"stars": q, "notes": notes, "name": info["name"], "recipe": info["recipe"]}


# ---------------------------------------------------------------- recipe text

static func describe_spec(sp: Dictionary) -> String:
	var names := []
	var cut := 0
	var whole := false
	for alt in sp["alts"]:
		if alt["any"]:
			names.append("anything")
		elif not (alt["cats"] as Array).is_empty():
			var c: String = alt["cats"][0]
			names.append({"veg": "any veg", "fruit": "any fruit", "meat": "any meat",
				"fish": "any fish"}.get(c, "any " + c))
		else:
			names.append(ING[alt["id"]][0])
		cut = maxi(cut, int(alt["cut"]))
		whole = whole or alt["whole"]
	var s := " or ".join(names)
	var steps := []
	if cut >= 3:
		steps.append("blend")
	elif cut > 0:
		var first: String = sp["alts"][0]["id"]
		var word: String = cut_word(first, cut) if first != "" else DEFAULT_CUT_WORDS[cut]
		steps.append(CUT_VERB.get(word, "chop"))
	if whole:
		steps.append("keep whole")
	if sp["raw"]:
		steps.append("raw")
	elif sp["any_cook"]:
		steps.append("cook")
	else:
		var ms := []
		for m in sp["m"]:
			ms.append(STATION_OF[m])
		if not ms.is_empty():
			steps.append(" / ".join(ms))
	if not steps.is_empty():
		s += " > " + " > ".join(steps)
	return s


## How to make an intermediate ingredient, e.g. "Batter = Flour + Egg + Milk in Mixing Bowl".
static func how_to(id: String) -> String:
	init()
	if not _how.has(id):
		return ""
	var r: Array = _how[id]
	var parts := []
	for s in r[1]:
		parts.append(describe_spec(parse(s)))
	return "%s = %s in %s" % [ING[id][0], " + ".join(parts), STATION_OF[r[0]]]


static func recipe_lines(k: int) -> Array:
	var rec := recipe(k)
	var lines := []
	var hows := []
	for sp in rec["specs"]:
		lines.append(describe_spec(sp))
		for alt in sp["alts"]:
			var id: String = alt["id"]
			if id != "" and flag(id, "i"):
				var h := how_to(id)
				if h != "" and not hows.has(h):
					hows.append(h)
					# one level deeper (e.g. pizza needs dough & tomato sauce)
					for s2 in _how[id][1]:
						var p2 := parse(s2)
						for a2 in p2["alts"]:
							var id2: String = a2["id"]
							if id2 != "" and flag(id2, "i"):
								var h2 := how_to(id2)
								if h2 != "" and not hows.has(h2):
									hows.append(h2)
	return [lines, hows]


## Rough number of prep steps, counting what it takes to make each intermediate.
static func difficulty(k: int) -> int:
	var d := 0
	for sp in recipe(k)["specs"]:
		d += _spec_cost(sp, 0)
	return d


static func _spec_cost(sp: Dictionary, depth: int) -> int:
	var d := 1 + int(sp["detail"])
	var id: String = sp["alts"][0]["id"]
	if id != "" and flag(id, "i") and _how.has(id) and depth < 3:
		for s in _how[id][1]:
			d += _spec_cost(parse(s), depth + 1)
	return d


static func display_name(k: int) -> String:
	return String(recipe(k)["name"]).replace("{} ", "")
