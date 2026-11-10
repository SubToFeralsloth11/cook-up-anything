class_name DB
extends RefCounted
## All food knowledge: ingredients, transformation rules, named recipes,
## dish naming, quality scoring and recipe-step text.
##
## Food data is a Dictionary. A leaf ingredient looks like:
##   {id, cut, style, pieces, coat, washed, cook, cooked, cold, burnt, pm, prog, br, ch,
##    portion?, flavor?, sstyle?, path?}
## A combined food is {id:"mix", parts:[leaves...], how:method}.

# id: [name, category, shape, outer hex, inner hex, size, flags, cooked hex?]
# flags: d=needs washing  x=can't be cut  r=unsafe raw  n=finished food
#        l=liquid  s=seasoning  i=made in the kitchen (not in the pantry)
# Raw ingredient models are rescaled to REAL (see below), so `size` only matters
# for kitchen-made food.
const ING := {
	# --- Vegetables ---
	"tomato": ["Tomato", "veg", "round", "e8352b", "f25c45", 0.085, "d"],
	"cherry_tomato": ["Cherry Tomatoes", "veg", "berries", "e53935", "f26b5b", 0.05, "d"],
	"onion": ["Onion", "veg", "round", "c98a4b", "f3ead9", 0.08, "d"],
	"red_onion": ["Red Onion", "veg", "round", "7b2c5a", "e8c8dc", 0.08, "d"],
	"shallot": ["Shallot", "veg", "garlic", "b06a50", "f0d8d0", 0.05, "ds"],
	"garlic": ["Garlic", "veg", "garlic", "f1ece0", "f7f3e8", 0.05, "ds"],
	"potato": ["Potato", "veg", "potato", "b88a4e", "f0dca0", 0.09, "d"],
	"sweet_potato": ["Sweet Potato", "veg", "potato", "9c4a2e", "f59a3e", 0.09, "d"],
	"carrot": ["Carrot", "veg", "carrot", "f07a1a", "f59a3e", 0.16, "d"],
	"beetroot": ["Beetroot", "veg", "round", "6a1b3a", "b0204e", 0.08, "d"],
	"radish": ["Radish", "veg", "round", "d81b60", "fafafa", 0.05, "d"],
	"lettuce": ["Lettuce", "veg", "leafy", "7fc94a", "b9e58a", 0.12, "d"],
	"cucumber": ["Cucumber", "veg", "long", "2f7d32", "cfe8a9", 0.18, "d"],
	"bell_pepper": ["Bell Pepper", "veg", "pepper", "e53935", "f26b5b", 0.09, "d"],
	"green_pepper": ["Green Pepper", "veg", "pepper", "43a047", "8bc34a", 0.09, "d"],
	"yellow_pepper": ["Yellow Pepper", "veg", "pepper", "fbc02d", "ffe082", 0.09, "d"],
	"chili": ["Chili", "veg", "chili", "d32f2f", "e85a4f", 0.09, "ds"],
	"jalapeno": ["Jalapeño", "veg", "chili", "2e7d32", "a5d6a7", 0.07, "ds"],
	"mushroom": ["Mushroom", "veg", "mushroom", "c8b49a", "efe5d6", 0.07, "d"],
	"broccoli": ["Broccoli", "veg", "broccoli", "3f8f3a", "7bbf5a", 0.1, "d"],
	"cauliflower": ["Cauliflower", "veg", "broccoli", "f3ecd8", "fbf6e8", 0.1, "d"],
	"spinach": ["Spinach", "veg", "leafy", "2e7d32", "4caf50", 0.1, "d"],
	"kale": ["Kale", "veg", "leafy", "1b5e20", "388e3c", 0.1, "d"],
	"cabbage": ["Cabbage", "veg", "leafy", "a5d6a7", "dcedc8", 0.13, "d"],
	"red_cabbage": ["Red Cabbage", "veg", "leafy", "6a1b9a", "ce93d8", 0.13, "d"],
	"bok_choy": ["Bok Choy", "veg", "leafy", "4caf50", "e8f5e9", 0.12, "d"],
	"corn": ["Corn", "veg", "corn", "f5c518", "f7d64a", 0.16, "d"],
	"zucchini": ["Zucchini", "veg", "long", "4b8b3b", "e6edb5", 0.17, "d"],
	"eggplant": ["Eggplant", "veg", "eggplant", "4a2a5c", "ece3c8", 0.15, "d"],
	"pumpkin": ["Pumpkin", "veg", "pumpkin", "f57c00", "ffa040", 0.14, "d"],
	"butternut": ["Butternut Squash", "veg", "eggplant", "e8b86a", "f59a3e", 0.15, "d"],
	"scallion": ["Scallion", "veg", "scallion", "66bb6a", "f1f8e9", 0.18, "ds"],
	"leek": ["Leek", "veg", "scallion", "558b2f", "f1f8e9", 0.2, "d"],
	"celery": ["Celery", "veg", "scallion", "9ccc65", "dcedc8", 0.2, "d"],
	"asparagus": ["Asparagus", "veg", "scallion", "558b2f", "c5e1a5", 0.18, "d"],
	"green_beans": ["Green Beans", "veg", "chili", "43a047", "a5d6a7", 0.09, "d"],
	"peas": ["Peas", "veg", "berries", "7cb342", "9ccc65", 0.05, "dx"],
	"ginger": ["Ginger", "veg", "potato", "c9a36a", "f3df9c", 0.06, "ds"],
	"basil": ["Basil", "veg", "herb", "2e8b3a", "3fa34d", 0.06, "ds"],
	"mint": ["Mint", "veg", "herb", "43a047", "66bb6a", 0.06, "ds"],
	"parsley": ["Parsley", "veg", "herb", "2e7d32", "43a047", 0.06, "ds"],
	"cilantro": ["Cilantro", "veg", "herb", "388e3c", "4caf50", 0.06, "ds"],
	"rosemary": ["Rosemary", "veg", "herb", "33691e", "558b2f", 0.06, "ds"],
	# --- Fruit ---
	"avocado": ["Avocado", "fruit", "avocado", "3b5323", "c5e17a", 0.08, "d"],
	"lemon": ["Lemon", "fruit", "lemon", "f9e04b", "fff59d", 0.07, "ds"],
	"lime": ["Lime", "fruit", "lemon", "7cb342", "c5e1a5", 0.06, "ds"],
	"apple": ["Apple", "fruit", "round", "c62828", "fff3c4", 0.08, "d"],
	"green_apple": ["Green Apple", "fruit", "round", "8bc34a", "fff9c4", 0.08, "d"],
	"pear": ["Pear", "fruit", "avocado", "c0ca33", "fffde7", 0.08, "d"],
	"peach": ["Peach", "fruit", "round", "ffab76", "ffcc80", 0.08, "d"],
	"plum": ["Plum", "fruit", "round", "5e2750", "f9a825", 0.06, "d"],
	"banana": ["Banana", "fruit", "banana", "f7d348", "fff4c2", 0.18, ""],
	"strawberry": ["Strawberry", "fruit", "strawberry", "e53935", "f48a8a", 0.05, "d"],
	"raspberry": ["Raspberries", "fruit", "berries", "d81b60", "f06292", 0.05, "dx"],
	"blueberry": ["Blueberries", "fruit", "berries", "3949ab", "5c6bc0", 0.05, "dx"],
	"cherry": ["Cherries", "fruit", "berries", "a4161a", "c62828", 0.05, "dx"],
	"grapes": ["Grapes", "fruit", "berries", "6a1b9a", "ba68c8", 0.05, "dx"],
	"orange": ["Orange", "fruit", "round", "fb8c00", "ffb74d", 0.085, "d"],
	"grapefruit": ["Grapefruit", "fruit", "round", "ffb74d", "ef5350", 0.09, "d"],
	"pineapple": ["Pineapple", "fruit", "pineapple", "e0b23a", "f7e27a", 0.2, "d"],
	"mango": ["Mango", "fruit", "mango", "f9a825", "ffc947", 0.09, "d"],
	"kiwi": ["Kiwi", "fruit", "potato", "8d6e63", "8bc34a", 0.06, "d"],
	"watermelon": ["Watermelon", "fruit", "pumpkin", "2e7d32", "ef5350", 0.2, "d"],
	"coconut": ["Coconut", "fruit", "potato", "6d4c41", "fafafa", 0.1, ""],
	"pomegranate": ["Pomegranate", "fruit", "round", "b71c1c", "e53950", 0.08, ""],
	# --- Meat ---
	"chicken": ["Chicken Drumstick", "meat", "drumstick", "f2c9b8", "f5d5c8", 0.12, "r", "d99a4e"],
	"chicken_breast": ["Chicken Breast", "meat", "fillet", "f4cfc0", "f8ddd2", 0.12, "r", "e0b070"],
	"chicken_wings": ["Chicken Wings", "meat", "drumstick", "f0c4b0", "f5d5c8", 0.08, "r", "c9782e"],
	"beef": ["Steak", "meat", "steak", "b0303a", "c2414b", 0.13, "r", "6d3b22"],
	"ground_beef": ["Ground Beef", "meat", "mince", "c0424a", "cc5a60", 0.1, "r", "6b4226"],
	"pork_chop": ["Pork Chop", "meat", "steak", "e8a0a0", "f2c0bc", 0.12, "r", "b07a4a"],
	"pork_mince": ["Pork Mince", "meat", "mince", "e8a5a5", "f2c4c0", 0.1, "r", "a0703e"],
	"pork_belly": ["Pork Belly", "meat", "steak", "e8b0a8", "fae0d8", 0.12, "r", "a65a2a"],
	"ribs": ["Ribs", "meat", "steak", "b8484a", "d06060", 0.14, "r", "6b2e18"],
	"lamb_chop": ["Lamb Chop", "meat", "steak", "a8323c", "c24a52", 0.1, "r", "6a3820"],
	"lamb_mince": ["Lamb Mince", "meat", "mince", "b04048", "c25860", 0.1, "r", "6d4026"],
	"duck": ["Duck Breast", "meat", "steak", "9a2a30", "b8404a", 0.11, "r", "7a3a1a"],
	"turkey": ["Turkey Breast", "meat", "fillet", "f0d0c4", "f8e0d6", 0.13, "r", "d8a060"],
	"bacon": ["Bacon", "meat", "bacon", "e57373", "f8bbd0", 0.12, "r", "a0402a"],
	"sausage": ["Sausage", "meat", "sausage", "d98880", "e6a29a", 0.13, "r", "8d4a25"],
	"frankfurter": ["Hot Dog Sausage", "meat", "sausage", "e58a6a", "f0a48a", 0.13, "", "b5532e"],
	"chorizo": ["Chorizo", "meat", "sausage", "b23a20", "d0502e", 0.12, ""],
	"ham": ["Ham", "meat", "ham", "f4a7b0", "f8c3c9", 0.11, ""],
	"prosciutto": ["Prosciutto", "meat", "ham", "d9707a", "f0a0a8", 0.11, ""],
	"salami": ["Salami", "meat", "disc", "a8322a", "c84a40", 0.07, ""],
	"pepperoni": ["Pepperoni", "meat", "disc", "b33a2e", "c94a3b", 0.07, ""],
	"turkey_slices": ["Turkey Slices", "meat", "ham", "f0d8c8", "f8e8dc", 0.11, ""],
	# --- Fish & seafood ---
	"salmon": ["Salmon", "fish", "fillet", "fa8c6a", "ffab91", 0.13, "r", "e8a27a"],
	"white_fish": ["White Fish", "fish", "fillet", "eceff1", "fafafa", 0.13, "r", "e0b070"],
	"tuna": ["Tuna Steak", "fish", "steak", "a8283a", "c2404e", 0.12, "r", "9a7060"],
	"smoked_salmon": ["Smoked Salmon", "fish", "ham", "f47a50", "ff9e7a", 0.1, ""],
	"shrimp": ["Shrimp", "fish", "shrimp", "c9b8b0", "e0d0c8", 0.06, "r", "ff8a65"],
	"crab": ["Crab Meat", "fish", "mince", "f5e6d8", "ffccbc", 0.09, "", "f5c8a8"],
	"squid": ["Squid", "fish", "sausage", "f5f0ea", "fafafa", 0.12, "r", "f0d8a8"],
	"mussels": ["Mussels", "fish", "berries", "263238", "ffb74d", 0.06, "rx", "37474f"],
	"canned_tuna": ["Canned Tuna", "fish", "can", "d8b8a0", "d8b8a0", 0.07, "x"],
	"anchovies": ["Anchovies", "fish", "can", "8d6e63", "8d6e63", 0.06, "xs"],
	"tofu": ["Tofu", "protein", "box", "f5f0e0", "fbf8ee", 0.07, ""],
	# --- Dairy & eggs ---
	"egg": ["Egg", "dairy", "egg", "f3e1c4", "ffd54f", 0.06, ""],
	"milk": ["Milk", "dairy", "carton", "ffffff", "f5f5f5", 0.12, "xl"],
	"buttermilk": ["Buttermilk", "dairy", "carton", "fffde7", "fffde7", 0.12, "xl"],
	"butter": ["Butter", "dairy", "box", "fff176", "fff59d", 0.05, ""],
	"cheese": ["Cheddar", "dairy", "wedge", "ffca28", "ffd54f", 0.08, ""],
	"mozzarella": ["Mozzarella", "dairy", "round", "fafafa", "ffffff", 0.07, ""],
	"parmesan": ["Parmesan", "dairy", "wedge", "f0d68a", "f5e3a8", 0.07, ""],
	"feta": ["Feta", "dairy", "box", "fafaf5", "ffffff", 0.06, ""],
	"halloumi": ["Halloumi", "dairy", "box", "f5f0dc", "fbf8ee", 0.06, ""],
	"brie": ["Brie", "dairy", "wedge", "f5f0e0", "fff3c4", 0.07, ""],
	"blue_cheese": ["Blue Cheese", "dairy", "wedge", "eceff1", "cfd8dc", 0.07, ""],
	"goat_cheese": ["Goat Cheese", "dairy", "round", "fafafa", "ffffff", 0.05, ""],
	"cream_cheese": ["Cream Cheese", "dairy", "tub", "fafafa", "ffffff", 0.07, "x"],
	"ricotta": ["Ricotta", "dairy", "tub", "fffdf5", "ffffff", 0.07, "x"],
	"sour_cream": ["Sour Cream", "dairy", "tub", "fffdf5", "ffffff", 0.07, "x"],
	"cream": ["Cream", "dairy", "carton", "fff8e1", "fffde7", 0.11, "xl"],
	"yogurt": ["Yogurt", "dairy", "tub", "fffdf5", "ffffff", 0.08, "xl"],
	"ice_cream": ["Ice Cream", "dairy", "tub", "f8bbd0", "fce4ec", 0.09, "x"],
	"condensed_milk": ["Condensed Milk", "dairy", "can", "fff3c4", "fff3c4", 0.07, "xl"],
	# --- Bread & bakery ---
	"bread": ["Bread", "grain", "loaf", "d9a05b", "f5e1b5", 0.15, ""],
	"bun": ["Burger Bun", "grain", "bun", "e0a050", "f5e1b5", 0.08, ""],
	"brioche_bun": ["Brioche Bun", "grain", "bun", "c8782e", "fbe3a8", 0.08, ""],
	"hot_dog_bun": ["Hot Dog Bun", "grain", "hdbun", "e0a050", "f5e1b5", 0.08, ""],
	"bagel": ["Bagel", "grain", "bagel", "d4994a", "f3dfb0", 0.07, ""],
	"croissant": ["Croissant", "grain", "croissant", "d99236", "f7dca0", 0.08, ""],
	"baguette": ["Baguette", "grain", "loaf", "d9953e", "f5e1b5", 0.15, ""],
	"english_muffin": ["English Muffin", "grain", "bun", "e8cc98", "f5e8c8", 0.07, ""],
	"pita": ["Pita", "grain", "tortilla", "e8c890", "f5e1b5", 0.1, ""],
	"naan": ["Naan", "grain", "tortilla", "e8c080", "f5e1b5", 0.12, ""],
	"tortilla": ["Tortilla", "grain", "tortilla", "f3dfb0", "f3dfb0", 0.12, ""],
	"taco_shell": ["Taco Shells", "grain", "chips", "f2c04a", "f2c04a", 0.08, "x"],
	"waffle": ["Frozen Waffles", "grain", "toast", "e0a64a", "f5d58a", 0.08, ""],
	"crumpet": ["Crumpets", "grain", "bun", "e8c890", "f5e1b5", 0.06, ""],
	"puff_pastry": ["Puff Pastry", "grain", "sheet", "f5e1b5", "f5e1b5", 0.1, "r", "d99236"],
	"rice_paper": ["Rice Paper", "grain", "sheet", "f5f2ea", "f5f2ea", 0.1, ""],
	"wonton_wrappers": ["Wonton Wrappers", "grain", "sheet", "f7e6b5", "f7e6b5", 0.08, ""],
	"crackers": ["Crackers", "grain", "chips", "e8b860", "e8b860", 0.07, "x"],
	"biscuits": ["Biscuits", "grain", "cookies", "d9a560", "c98a3e", 0.07, "x"],
	# --- Dry goods ---
	"flour": ["Flour", "grain", "sack", "f5f0e6", "ffffff", 0.1, "x"],
	"cornflour": ["Cornflour", "grain", "sack", "fff8e1", "ffffff", 0.09, "x"],
	"sugar": ["Sugar", "grain", "sack", "ffffff", "ffffff", 0.09, "xs"],
	"brown_sugar": ["Brown Sugar", "grain", "sack", "a0703a", "b07a40", 0.09, "xs"],
	"icing_sugar": ["Icing Sugar", "grain", "sack", "fafafa", "ffffff", 0.09, "xs"],
	"rice": ["Rice", "grain", "sack", "f2efe6", "fafafa", 0.1, "x"],
	"pasta": ["Spaghetti", "grain", "pasta", "f3d27a", "f3d27a", 0.16, "x"],
	"penne": ["Penne", "grain", "sack", "f3d27a", "f3d27a", 0.09, "x"],
	"macaroni": ["Macaroni", "grain", "sack", "f5d880", "f5d880", 0.09, "x"],
	"lasagne_sheets": ["Lasagne Sheets", "grain", "sheet", "f3d27a", "f3d27a", 0.1, "x"],
	"noodles": ["Egg Noodles", "grain", "noodles", "f5dfa0", "f5dfa0", 0.1, "x"],
	"rice_noodles": ["Rice Noodles", "grain", "noodles", "f5f2ea", "f5f2ea", 0.1, "x"],
	"couscous": ["Couscous", "grain", "sack", "f0d890", "f0d890", 0.09, "x"],
	"quinoa": ["Quinoa", "grain", "sack", "e8d4a8", "e8d4a8", 0.09, "x"],
	"lentils": ["Lentils", "grain", "sack", "e07a3a", "e07a3a", 0.09, "x"],
	"oats": ["Oats", "grain", "sack", "e8d5a8", "e8d5a8", 0.09, "x"],
	"granola": ["Granola", "grain", "sack", "c8904a", "c8904a", 0.09, "x"],
	"cereal": ["Cereal", "grain", "sack", "f0b040", "f0b040", 0.09, "x"],
	"breadcrumbs": ["Breadcrumbs", "grain", "sack", "e0b060", "e0b060", 0.08, "x"],
	"panko": ["Panko", "grain", "sack", "f5dca0", "f5dca0", 0.08, "x"],
	"nori": ["Nori", "grain", "sheet", "1b3a1b", "1b3a1b", 0.1, "x"],
	"chickpeas": ["Chickpeas", "grain", "can", "e8c88a", "e8c88a", 0.08, "x"],
	"beans": ["Baked Beans", "grain", "can", "b5462f", "b5462f", 0.08, "x"],
	"black_beans": ["Black Beans", "grain", "can", "2b2b2b", "3a3030", 0.08, "x"],
	"kidney_beans": ["Kidney Beans", "grain", "can", "8b2a2a", "9a3434", 0.08, "x"],
	"canned_tomatoes": ["Chopped Tomatoes", "grain", "can", "c62828", "d32f2f", 0.08, "xl"],
	"sweetcorn": ["Sweetcorn", "grain", "can", "f5c518", "f7d64a", 0.08, "x"],
	"peanuts": ["Peanuts", "grain", "jar", "c8945a", "c8945a", 0.07, "x"],
	"almonds": ["Almonds", "grain", "jar", "a0683a", "f0e0c8", 0.07, "x"],
	"walnuts": ["Walnuts", "grain", "jar", "a07850", "c8a070", 0.07, "x"],
	"cashews": ["Cashews", "grain", "jar", "e8d0a0", "f0dcb0", 0.07, "x"],
	"raisins": ["Raisins", "grain", "jar", "4a2a2a", "5a3434", 0.06, "x"],
	"coconut_flakes": ["Coconut Flakes", "grain", "sack", "fafafa", "ffffff", 0.07, "x"],
	"tea": ["Tea Bags", "grain", "jar", "6d4c41", "8d6e63", 0.06, "x"],
	"coffee": ["Coffee", "grain", "jar", "3e2723", "4e342e", 0.06, "x"],
	"gelatin": ["Jelly Crystals", "grain", "sack", "e53950", "e53950", 0.06, "x"],
	"yeast": ["Yeast", "grain", "jar", "e8d4a8", "e8d4a8", 0.05, "x"],
	# --- Spices & seasoning ---
	"salt": ["Salt", "spice", "shaker", "ffffff", "ffffff", 0.06, "xs"],
	"black_pepper": ["Black Pepper", "spice", "mill", "3e3e3e", "3e3e3e", 0.06, "xs"],
	"herbs": ["Mixed Herbs", "spice", "jar", "558b2f", "689f38", 0.06, "xs"],
	"oregano": ["Oregano", "spice", "jar", "6b8e23", "6b8e23", 0.06, "xs"],
	"paprika": ["Paprika", "spice", "jar", "c0392b", "c0392b", 0.06, "xs"],
	"cumin": ["Cumin", "spice", "jar", "a0702a", "a0702a", 0.06, "xs"],
	"chili_flakes": ["Chili Flakes", "spice", "jar", "b71c1c", "d84315", 0.06, "xs"],
	"garlic_powder": ["Garlic Powder", "spice", "jar", "f0e0b0", "f0e0b0", 0.06, "xs"],
	"curry_powder": ["Curry Powder", "spice", "jar", "e6a817", "e6a817", 0.06, "xs"],
	"garam_masala": ["Garam Masala", "spice", "jar", "8d5a2a", "8d5a2a", 0.06, "xs"],
	"turmeric": ["Turmeric", "spice", "jar", "f9a825", "f9a825", 0.06, "xs"],
	"cajun": ["Cajun Spice", "spice", "jar", "c0502a", "c0502a", 0.06, "xs"],
	"cinnamon": ["Cinnamon", "spice", "jar", "8d5524", "8d5524", 0.06, "xs"],
	"nutmeg": ["Nutmeg", "spice", "jar", "8a6040", "8a6040", 0.06, "xs"],
	"sesame_seeds": ["Sesame Seeds", "spice", "jar", "f0e0b8", "f0e0b8", 0.06, "xs"],
	"vanilla": ["Vanilla", "spice", "bottle", "5d4037", "5d4037", 0.06, "xs"],
	# --- Sauces, oils & condiments ---
	"oil": ["Vegetable Oil", "sauce", "bottle", "e8c547", "e8c547", 0.12, "xl"],
	"olive_oil": ["Olive Oil", "sauce", "bottle", "9a9a2a", "b5b53a", 0.12, "xls"],
	"sesame_oil": ["Sesame Oil", "sauce", "bottle", "b07a2a", "c08a3a", 0.1, "xls"],
	"vinegar": ["Vinegar", "sauce", "bottle", "f0e8c8", "f0e8c8", 0.1, "xls"],
	"balsamic": ["Balsamic", "sauce", "bottle", "2a1a14", "3a2418", 0.1, "xls"],
	"soy_sauce": ["Soy Sauce", "sauce", "bottle", "3e2723", "3e2723", 0.11, "xls"],
	"fish_sauce": ["Fish Sauce", "sauce", "bottle", "8a5a2a", "9a6a30", 0.1, "xls"],
	"worcestershire": ["Worcestershire", "sauce", "bottle", "3a2014", "4a2a1a", 0.1, "xls"],
	"hoisin": ["Hoisin", "sauce", "bottle", "4a1a14", "5a2418", 0.1, "xls"],
	"teriyaki": ["Teriyaki Sauce", "sauce", "bottle", "4a2a14", "5a341c", 0.1, "xls"],
	"sweet_chili": ["Sweet Chili Sauce", "sauce", "bottle", "e64a19", "ff7043", 0.1, "xls"],
	"hot_sauce": ["Hot Sauce", "sauce", "bottle", "c62828", "d32f2f", 0.08, "xls"],
	"ketchup": ["Ketchup", "sauce", "squeeze", "d32f2f", "d32f2f", 0.11, "xls"],
	"mustard": ["Mustard", "sauce", "squeeze", "fbc02d", "fbc02d", 0.11, "xls"],
	"bbq_sauce": ["BBQ Sauce", "sauce", "squeeze", "5d2a14", "6d3418", 0.11, "xls"],
	"sriracha": ["Sriracha", "sauce", "squeeze", "e53935", "e53935", 0.1, "xls"],
	"ranch": ["Ranch", "sauce", "squeeze", "f5f2e8", "f5f2e8", 0.1, "xls"],
	"mayonnaise": ["Mayonnaise", "sauce", "squeeze", "fff3c4", "fff3c4", 0.1, "xls"],
	"tomato_paste": ["Tomato Paste", "sauce", "squeeze", "b71c1c", "b71c1c", 0.08, "xls"],
	"broth": ["Broth", "sauce", "carton", "d7a86e", "d7a86e", 0.12, "xl"],
	"coconut_milk": ["Coconut Milk", "sauce", "can", "f5f5f5", "fafafa", 0.08, "xl"],
	"peanut_butter": ["Peanut Butter", "sauce", "jar", "b07a3a", "b07a3a", 0.07, "x"],
	"tahini": ["Tahini", "sauce", "jar", "d8b88a", "d8b88a", 0.07, "xl"],
	"miso": ["Miso", "sauce", "tub", "c8904a", "c8904a", 0.06, "xs"],
	"gochujang": ["Gochujang", "sauce", "tub", "a8281e", "b8302a", 0.06, "xs"],
	"curry_paste": ["Curry Paste", "sauce", "jar", "c0402a", "c0402a", 0.06, "xs"],
	"pickles": ["Pickles", "sauce", "jar", "689f38", "9ccc65", 0.08, ""],
	"olives": ["Olives", "sauce", "jar", "3a3a2a", "556b2f", 0.07, "x"],
	"capers": ["Capers", "sauce", "jar", "556b2f", "6b8e23", 0.05, "xs"],
	"honey": ["Honey", "sauce", "jar", "f9a825", "f9a825", 0.07, "xl"],
	# --- Sweets ---
	"chocolate": ["Chocolate", "sweet", "bar", "5d3a1a", "6d4423", 0.08, ""],
	"white_chocolate": ["White Chocolate", "sweet", "bar", "f5ecd8", "fff8e8", 0.08, ""],
	"cocoa": ["Cocoa Powder", "sweet", "can", "4e2c12", "4e2c12", 0.06, "xs"],
	"choc_spread": ["Chocolate Spread", "sweet", "jar", "4a2a14", "5a3418", 0.07, "x"],
	"maple_syrup": ["Maple Syrup", "sweet", "bottle", "b5651d", "b5651d", 0.1, "xl"],
	"golden_syrup": ["Golden Syrup", "sweet", "can", "e8a420", "e8a420", 0.07, "xl"],
	"jam": ["Jam", "sweet", "jar", "b71c4a", "b71c4a", 0.07, "x"],
	"sprinkles": ["Sprinkles", "sweet", "jar", "ff80ab", "ff80ab", 0.06, "xs"],
	"marshmallow": ["Marshmallows", "sweet", "marsh", "fafafa", "fafafa", 0.05, "x", "d9a066"],
	"gummy_bears": ["Gummy Bears", "sweet", "marsh", "ff5252", "ffeb3b", 0.04, "x"],
	# --- Made in the kitchen ---
	"beaten_egg": ["Beaten Egg", "made", "bowl", "ffd54f", "ffd54f", 0.08, "ixl"],
	"fried_egg": ["Fried Egg", "made", "friedegg", "ffffff", "ffc107", 0.08, "inx"],
	"poached_egg": ["Poached Egg", "made", "friedegg", "fafafa", "ffb300", 0.07, "inx"],
	"boiled_egg": ["Boiled Egg", "made", "egg", "f5f5f5", "ffd54f", 0.06, "in"],
	"scrambled_eggs": ["Scrambled Eggs", "made", "mound", "ffe082", "ffe082", 0.08, "inx"],
	"batter": ["Batter", "made", "bowl", "f3e5ab", "f3e5ab", 0.08, "irxl"],
	"cake_batter": ["Cake Batter", "made", "bowl", "f8e1a8", "f8e1a8", 0.08, "irxl"],
	"cookie_dough": ["Cookie Dough", "made", "dough", "d9b779", "d9b779", 0.08, "ix"],
	"dough": ["Dough", "made", "dough", "f3e3c0", "f3e3c0", 0.09, "ir"],
	"pasta_dough": ["Pasta Dough", "made", "dough", "f5d77a", "f5d77a", 0.08, "ir"],
	"pastry": ["Pastry", "made", "dough", "f5e1b5", "f5e1b5", 0.08, "ir"],
	"patty": ["Patty", "made", "patty", "c0424a", "c0424a", 0.08, "irx", "6b3a22"],
	"meatballs": ["Meatballs", "made", "balls", "c0424a", "c0424a", 0.07, "irx", "7a4228"],
	"falafel": ["Falafel", "made", "balls", "8a9a4a", "a8b860", 0.07, "irx", "8a5a24"],
	"hash_browns": ["Hash Browns", "made", "patty", "f0dca0", "f0dca0", 0.07, "inx"],
	"roast_potatoes": ["Roast Potatoes", "made", "balls", "e0a040", "f0dca0", 0.07, "inx"],
	"whipped_cream": ["Whipped Cream", "made", "bowlmound", "ffffff", "ffffff", 0.08, "inx"],
	"mayo": ["Homemade Mayo", "made", "bowl", "fff3c4", "fff3c4", 0.07, "inxls"],
	"aioli": ["Aioli", "made", "bowl", "fff0b0", "fff0b0", 0.07, "inxls"],
	"vinaigrette": ["Vinaigrette", "made", "bowl", "c8b040", "c8b040", 0.07, "inxls"],
	"garlic_butter": ["Garlic Butter", "made", "bowl", "fff176", "fff176", 0.07, "inxs"],
	"tzatziki": ["Tzatziki", "made", "bowl", "f0f5e8", "f0f5e8", 0.07, "inx"],
	"frosting": ["Frosting", "made", "bowlmound", "fff0f5", "fff0f5", 0.07, "inx"],
	"tomato_sauce": ["Tomato Sauce", "made", "bowl", "c62828", "c62828", 0.08, "inxl"],
	"gravy": ["Gravy", "made", "bowl", "6d4020", "6d4020", 0.08, "inxl"],
	"cheese_sauce": ["Cheese Sauce", "made", "bowl", "ffc840", "ffc840", 0.08, "inxl"],
	"custard": ["Custard", "made", "bowl", "ffe082", "ffe082", 0.08, "inxl"],
	"salsa": ["Salsa", "made", "bowlchunks", "e53935", "e53935", 0.08, "inx"],
	"guacamole": ["Guacamole", "made", "bowl", "9ccc65", "9ccc65", 0.08, "inx"],
	"pesto": ["Pesto", "made", "bowl", "4caf50", "4caf50", 0.07, "inxl"],
	"hummus": ["Hummus", "made", "bowl", "e6cc8f", "e6cc8f", 0.08, "inx"],
	"mashed_potato": ["Mashed Potato", "made", "mound", "fff3c0", "fff3c0", 0.09, "inx"],
	"fries": ["Fries", "made", "fries", "f9c74f", "f9c74f", 0.08, "inx"],
	"sweet_potato_fries": ["Sweet Potato Fries", "made", "fries", "e8782a", "e8782a", 0.08, "inx"],
	"crisps": ["Crisps", "made", "chips", "f9d56e", "f9d56e", 0.08, "inx"],
	"tortilla_chips": ["Tortilla Chips", "made", "chips", "f4c542", "f4c542", 0.08, "inx"],
	"steamed_rice": ["Steamed Rice", "made", "mound", "fafafa", "fafafa", 0.09, "inx"],
	"cooked_quinoa": ["Cooked Quinoa", "made", "mound", "e8d4a8", "e8d4a8", 0.09, "inx"],
	"cooked_couscous": ["Cooked Couscous", "made", "mound", "f0d890", "f0d890", 0.09, "inx"],
	"dal": ["Dal", "made", "bowl", "e8a030", "e8a030", 0.08, "inx"],
	"cooked_pasta": ["Cooked Spaghetti", "made", "noodlepile", "f5d77a", "f5d77a", 0.09, "inx"],
	"cooked_penne": ["Cooked Penne", "made", "noodlepile", "f5d77a", "f5d77a", 0.09, "inx"],
	"cooked_macaroni": ["Cooked Macaroni", "made", "noodlepile", "f7dc88", "f7dc88", 0.09, "inx"],
	"cooked_noodles": ["Cooked Noodles", "made", "noodlepile", "f7e0a0", "f7e0a0", 0.09, "inx"],
	"cooked_rice_noodles": ["Cooked Rice Noodles", "made", "noodlepile", "f8f5ee", "f8f5ee", 0.09, "inx"],
	"popcorn": ["Popcorn", "made", "popcorn", "fff8e1", "fff8e1", 0.08, "inx"],
	"caramel": ["Caramel", "made", "bowl", "c47a1d", "c47a1d", 0.07, "inxl"],
	"melted_chocolate": ["Melted Chocolate", "made", "bowl", "4e2c12", "4e2c12", 0.07, "inxl"],
	"toast": ["Toast", "made", "toast", "c98a3e", "f0d9a8", 0.08, "in"],
	"grilled_cheese": ["Grilled Cheese", "made", "sandwich", "d4943c", "ffca28", 0.08, "in"],
	"french_toast": ["French Toast", "made", "toast", "e0a64a", "f5d58a", 0.08, "in"],
	"bread_loaf": ["Fresh Bread", "made", "loaf", "c98a3e", "f5e1b5", 0.14, "in"],
	"pizza": ["Pizza", "made", "pizza", "e8b65a", "d84315", 0.12, "in"],
	"pie": ["Pie", "made", "pie", "d9a050", "b71c1c", 0.11, "in"],
	"quiche": ["Quiche", "made", "pie", "e0b060", "ffe082", 0.11, "in"],
	"cake": ["Cake", "made", "cake", "f8e1c0", "fce4ec", 0.1, "in"],
	"cheesecake": ["Cheesecake", "made", "cake", "f8ecd0", "fff8e8", 0.1, "in"],
	"tiramisu": ["Tiramisu", "made", "cake", "6d4c41", "f5e6c8", 0.1, "in"],
	"brownies": ["Brownies", "made", "toast", "4a2a14", "5a3418", 0.07, "in"],
	"flapjacks": ["Flapjacks", "made", "toast", "c8904a", "d8a860", 0.07, "in"],
	"muffins": ["Muffins", "made", "muffins", "d9a050", "8d6e63", 0.08, "inx"],
	"cookies": ["Cookies", "made", "cookies", "c98a3e", "4e342e", 0.08, "inx"],
	"pancakes": ["Pancakes", "made", "stack", "e8b060", "fff59d", 0.09, "in"],
	"donuts": ["Donuts", "made", "donuts", "d99a4e", "f8bbd0", 0.08, "inx"],
	"sausage_roll": ["Sausage Roll", "made", "loaf", "d99236", "c07040", 0.06, "in"],
	"spring_rolls": ["Spring Rolls", "made", "fries", "e0a040", "e0a040", 0.07, "inx"],
	"kebab": ["Kebab", "made", "skewer", "8d4a25", "c06030", 0.08, "in"],
	"smoothie": ["Smoothie", "made", "glass", "f48fb1", "f48fb1", 0.08, "inxl"],
	"juice": ["Juice", "made", "glass", "ffb74d", "ffb74d", 0.08, "inxl"],
	"milkshake": ["Milkshake", "made", "glass", "f8bbd0", "f8bbd0", 0.08, "inxl"],
	"lemonade": ["Lemonade", "made", "glass", "fff59d", "fff59d", 0.08, "inxl"],
	"iced_tea": ["Iced Tea", "made", "glass", "b5651d", "b5651d", 0.08, "inxl"],
	"iced_coffee": ["Iced Coffee", "made", "glass", "a0785a", "a0785a", 0.08, "inxl"],
	"frappe": ["Frappé", "made", "glass", "c8a080", "c8a080", 0.08, "inxl"],
	"hot_chocolate": ["Hot Chocolate", "made", "mug", "6d4c41", "6d4c41", 0.08, "inxl"],
	"brewed_tea": ["Cup of Tea", "made", "mug", "a0602a", "a0602a", 0.08, "inxl"],
	"brewed_coffee": ["Coffee", "made", "mug", "3e2723", "3e2723", 0.08, "inxl"],
	"mug_cake": ["Mug Cake", "made", "mug", "6d4423", "6d4423", 0.08, "inx"],
	"porridge": ["Porridge", "made", "bowl", "e8dcc0", "e8dcc0", 0.08, "inx"],
	"overnight_oats": ["Overnight Oats", "made", "bowl", "efe4cc", "efe4cc", 0.08, "inx"],
	"jelly": ["Jelly", "made", "mound", "e53950", "e53950", 0.08, "inx"],
	"chocolate_mousse": ["Chocolate Mousse", "made", "bowlmound", "5a3418", "5a3418", 0.08, "inx"],
	"ice_pop": ["Ice Pop", "made", "icepop", "ff7043", "ff7043", 0.06, "inx"],
	"frozen_yogurt": ["Frozen Yogurt", "made", "tub", "fce4ec", "fce4ec", 0.08, "inx"],
}

## Builder used to draw an ingredient that has no model of its own (its own colours are kept).
const LOOK := {
	"cherry_tomato": "blueberry", "red_onion": "onion", "shallot": "garlic", "sweet_potato": "potato",
	"beetroot": "onion", "radish": "onion", "green_pepper": "bell_pepper", "yellow_pepper": "bell_pepper",
	"jalapeno": "chili", "cauliflower": "broccoli", "kale": "spinach", "red_cabbage": "cabbage",
	"bok_choy": "lettuce", "butternut": "eggplant", "leek": "scallion", "celery": "scallion",
	"asparagus": "scallion", "green_beans": "chili", "peas": "blueberry", "mint": "basil",
	"parsley": "basil", "cilantro": "basil", "rosemary": "basil", "green_apple": "apple",
	"pear": "avocado", "peach": "apple", "plum": "apple", "raspberry": "blueberry", "cherry": "blueberry",
	"grapes": "blueberry", "grapefruit": "orange", "kiwi": "potato", "watermelon": "pumpkin",
	"coconut": "potato", "pomegranate": "apple", "chicken_breast": "white_fish", "chicken_wings": "chicken",
	"pork_chop": "beef", "pork_mince": "ground_beef", "pork_belly": "beef", "ribs": "beef",
	"lamb_chop": "beef", "lamb_mince": "ground_beef", "duck": "beef", "turkey": "white_fish",
	"frankfurter": "sausage", "chorizo": "sausage", "prosciutto": "ham", "salami": "pepperoni",
	"turkey_slices": "ham", "tuna": "beef", "smoked_salmon": "ham", "crab": "ground_beef", "squid": "sausage",
	"mussels": "blueberry", "canned_tuna": "beans", "anchovies": "beans", "buttermilk": "milk",
	"feta": "tofu", "halloumi": "tofu", "brie": "cheese", "blue_cheese": "parmesan", "goat_cheese": "mozzarella",
	"cream_cheese": "yogurt", "ricotta": "yogurt", "sour_cream": "yogurt", "condensed_milk": "beans",
	"brioche_bun": "bun", "english_muffin": "bun", "crumpet": "bun", "baguette": "bread", "pita": "tortilla",
	"naan": "tortilla", "taco_shell": "tortilla_chips", "waffle": "toast", "puff_pastry": "nori",
	"rice_paper": "nori", "wonton_wrappers": "nori", "lasagne_sheets": "nori", "crackers": "crisps",
	"biscuits": "cookies", "cornflour": "flour", "brown_sugar": "flour", "icing_sugar": "flour",
	"penne": "flour", "macaroni": "flour", "couscous": "flour", "quinoa": "flour", "lentils": "flour",
	"granola": "oats", "cereal": "flour", "panko": "flour", "coconut_flakes": "flour", "gelatin": "flour",
	"black_beans": "beans", "kidney_beans": "beans", "canned_tomatoes": "beans", "sweetcorn": "beans",
	"peanuts": "peanut_butter", "almonds": "peanut_butter", "walnuts": "peanut_butter", "cashews": "peanut_butter",
	"raisins": "jam", "tea": "honey", "coffee": "peanut_butter", "yeast": "honey", "rice_noodles": "noodles",
	"oregano": "herbs", "paprika": "curry_powder", "cumin": "curry_powder", "chili_flakes": "curry_powder",
	"garlic_powder": "herbs", "garam_masala": "cinnamon", "turmeric": "curry_powder", "cajun": "curry_powder",
	"nutmeg": "cinnamon", "sesame_seeds": "herbs", "olive_oil": "oil", "sesame_oil": "soy_sauce",
	"vinegar": "oil", "balsamic": "soy_sauce", "fish_sauce": "soy_sauce", "worcestershire": "soy_sauce",
	"hoisin": "soy_sauce", "teriyaki": "soy_sauce", "sweet_chili": "maple_syrup", "hot_sauce": "vanilla",
	"bbq_sauce": "ketchup", "sriracha": "ketchup", "ranch": "mustard", "mayonnaise": "mustard",
	"tomato_paste": "ketchup", "tahini": "peanut_butter", "miso": "yogurt", "gochujang": "yogurt",
	"curry_paste": "jam", "pickles": "jam", "olives": "jam", "capers": "honey", "white_chocolate": "chocolate",
	"cocoa": "beans", "choc_spread": "peanut_butter", "golden_syrup": "beans", "gummy_bears": "marshmallow",
	"poached_egg": "fried_egg", "pasta_dough": "dough", "pastry": "dough", "falafel": "meatballs",
	"hash_browns": "patty", "roast_potatoes": "meatballs", "aioli": "mayo", "vinaigrette": "tomato_sauce",
	"garlic_butter": "mayo", "tzatziki": "hummus", "frosting": "whipped_cream", "gravy": "tomato_sauce",
	"cheese_sauce": "tomato_sauce", "custard": "tomato_sauce", "sweet_potato_fries": "fries",
	"cooked_quinoa": "steamed_rice", "cooked_couscous": "steamed_rice", "dal": "guacamole",
	"cooked_penne": "cooked_pasta", "cooked_macaroni": "cooked_pasta", "cooked_rice_noodles": "cooked_noodles",
	"quiche": "pie", "cheesecake": "cake", "tiramisu": "cake", "brownies": "toast", "flapjacks": "toast",
	"sausage_roll": "bread_loaf", "spring_rolls": "fries", "iced_tea": "lemonade", "iced_coffee": "milkshake",
	"frappe": "milkshake", "brewed_tea": "hot_chocolate", "brewed_coffee": "hot_chocolate",
	"mug_cake": "hot_chocolate", "overnight_oats": "porridge", "jelly": "mashed_potato",
	"chocolate_mousse": "whipped_cream", "frozen_yogurt": "ice_cream",
}

## Real-world longest dimension in cm for shop-bought ingredients. Models are scaled
## to REAL x Models.K so everything in the kitchen sits at a consistent size.
const REAL := {
	"tomato": 7, "cherry_tomato": 8, "onion": 8, "red_onion": 8, "shallot": 5, "garlic": 5, "potato": 11,
	"sweet_potato": 15, "carrot": 18, "beetroot": 7, "radish": 4, "lettuce": 18, "cucumber": 22,
	"bell_pepper": 10, "green_pepper": 10, "yellow_pepper": 10, "chili": 9, "jalapeno": 7, "mushroom": 6,
	"broccoli": 15, "cauliflower": 16, "spinach": 18, "kale": 22, "cabbage": 18, "red_cabbage": 17,
	"bok_choy": 20, "corn": 20, "zucchini": 20, "eggplant": 20, "pumpkin": 25, "butternut": 25,
	"scallion": 28, "leek": 32, "celery": 30, "asparagus": 20, "green_beans": 12, "peas": 8, "ginger": 9,
	"basil": 12, "mint": 10, "parsley": 12, "cilantro": 12, "rosemary": 12, "avocado": 10, "lemon": 9,
	"lime": 6, "apple": 8, "green_apple": 8, "pear": 10, "peach": 7, "plum": 5, "banana": 19,
	"strawberry": 4, "raspberry": 7, "blueberry": 8, "cherry": 8, "grapes": 12, "orange": 8,
	"grapefruit": 11, "pineapple": 30, "mango": 12, "kiwi": 6, "watermelon": 28, "coconut": 12,
	"pomegranate": 9, "chicken": 14, "chicken_breast": 17, "chicken_wings": 10, "beef": 20,
	"ground_beef": 14, "pork_chop": 16, "pork_mince": 14, "pork_belly": 15, "ribs": 24, "lamb_chop": 12,
	"lamb_mince": 14, "duck": 15, "turkey": 20, "bacon": 22, "sausage": 13, "frankfurter": 15,
	"chorizo": 16, "ham": 16, "prosciutto": 16, "salami": 18, "pepperoni": 15, "turkey_slices": 15,
	"salmon": 18, "white_fish": 18, "tuna": 14, "smoked_salmon": 15, "shrimp": 7, "crab": 10,
	"squid": 14, "mussels": 10, "canned_tuna": 8, "anchovies": 7, "tofu": 10, "egg": 6, "milk": 22,
	"buttermilk": 20, "butter": 11, "cheese": 10, "mozzarella": 7, "parmesan": 10, "feta": 8,
	"halloumi": 9, "brie": 11, "blue_cheese": 9, "goat_cheese": 6, "cream_cheese": 9, "ricotta": 9,
	"sour_cream": 9, "cream": 16, "yogurt": 10, "ice_cream": 14, "condensed_milk": 8, "bread": 25,
	"bun": 10, "brioche_bun": 10, "hot_dog_bun": 17, "bagel": 10, "croissant": 14, "baguette": 50,
	"english_muffin": 9, "pita": 16, "naan": 22, "tortilla": 22, "taco_shell": 14, "waffle": 11,
	"crumpet": 8, "puff_pastry": 22, "rice_paper": 20, "wonton_wrappers": 9, "crackers": 12,
	"biscuits": 12, "flour": 22, "cornflour": 18, "sugar": 20, "brown_sugar": 18, "icing_sugar": 18,
	"rice": 22, "pasta": 26, "penne": 18, "macaroni": 18, "lasagne_sheets": 18, "noodles": 12,
	"rice_noodles": 14, "couscous": 16, "quinoa": 16, "lentils": 16, "oats": 15, "granola": 18,
	"cereal": 24, "breadcrumbs": 16, "panko": 16, "nori": 20, "chickpeas": 11, "beans": 11,
	"black_beans": 11, "kidney_beans": 11, "canned_tomatoes": 11, "sweetcorn": 9, "peanuts": 10,
	"almonds": 10, "walnuts": 10, "cashews": 10, "raisins": 9, "coconut_flakes": 14, "tea": 9,
	"coffee": 11, "gelatin": 10, "yeast": 7, "salt": 9, "black_pepper": 16, "herbs": 9, "oregano": 9,
	"paprika": 9, "cumin": 9, "chili_flakes": 9, "garlic_powder": 9, "curry_powder": 9,
	"garam_masala": 9, "turmeric": 9, "cajun": 9, "cinnamon": 9, "nutmeg": 9, "sesame_seeds": 9,
	"vanilla": 11, "oil": 28, "olive_oil": 28, "sesame_oil": 18, "vinegar": 24, "balsamic": 22,
	"soy_sauce": 18, "fish_sauce": 20, "worcestershire": 18, "hoisin": 18, "teriyaki": 18,
	"sweet_chili": 20, "hot_sauce": 14, "ketchup": 19, "mustard": 19, "bbq_sauce": 20, "sriracha": 19,
	"ranch": 19, "mayonnaise": 19, "tomato_paste": 14, "broth": 20, "coconut_milk": 11,
	"peanut_butter": 11, "tahini": 11, "miso": 9, "gochujang": 9, "curry_paste": 9, "pickles": 14,
	"olives": 11, "capers": 8, "honey": 11, "chocolate": 15, "white_chocolate": 15, "cocoa": 11,
	"choc_spread": 11, "maple_syrup": 20, "golden_syrup": 10, "jam": 10, "sprinkles": 9,
	"marshmallow": 9, "gummy_bears": 8,
}

const SHORT := {
	"steamed_rice": "Rice", "cooked_pasta": "Spaghetti", "cooked_noodles": "Noodle",
	"ground_beef": "Beef", "white_fish": "Fish", "bell_pepper": "Pepper", "green_pepper": "Pepper",
	"yellow_pepper": "Pepper", "black_pepper": "Peppered", "blueberry": "Blueberry", "marshmallow": "Marshmallow",
	"mashed_potato": "Mash", "scrambled_eggs": "Egg", "fried_egg": "Egg", "poached_egg": "Egg",
	"boiled_egg": "Egg", "beaten_egg": "Egg", "bread_loaf": "Bread", "tortilla_chips": "Nacho",
	"melted_chocolate": "Chocolate", "ice_cream": "Ice Cream", "maple_syrup": "Maple",
	"peanut_butter": "Peanut Butter", "coconut_milk": "Coconut", "curry_powder": "Curry",
	"soy_sauce": "Soy", "tomato_sauce": "Tomato", "whipped_cream": "Cream", "cake_batter": "Cake",
	"cookie_dough": "Cookie Dough", "chicken": "Chicken", "chicken_breast": "Chicken",
	"chicken_wings": "Wing", "beef": "Steak", "pork_mince": "Pork", "pork_chop": "Pork",
	"pork_belly": "Pork Belly", "lamb_mince": "Lamb", "lamb_chop": "Lamb", "duck": "Duck",
	"turkey": "Turkey", "turkey_slices": "Turkey", "frankfurter": "Frank", "cheese": "Cheese",
	"cherry_tomato": "Tomato", "red_onion": "Onion", "sweet_potato": "Sweet Potato",
	"cooked_quinoa": "Quinoa", "cooked_couscous": "Couscous", "cooked_penne": "Penne",
	"cooked_macaroni": "Macaroni", "cooked_rice_noodles": "Rice Noodle", "canned_tuna": "Tuna",
	"canned_tomatoes": "Tomato", "smoked_salmon": "Smoked Salmon", "choc_spread": "Chocolate",
	"brewed_tea": "Tea", "brewed_coffee": "Coffee", "olive_oil": "Olive Oil", "mayonnaise": "Mayo",
	"bbq_sauce": "BBQ", "hot_sauce": "Hot", "sweet_chili": "Sweet Chili", "kidney_beans": "Bean",
	"black_beans": "Black Bean", "green_beans": "Green Bean", "brioche_bun": "Brioche",
	"gummy_bears": "Gummy", "white_chocolate": "White Chocolate", "cocoa": "Cocoa",
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
	"mix": "Mixing Bowl", "blend": "Blender", "grill": "Grill", "microwave": "Microwave",
	"toast": "Toaster", "chill": "Fridge", "freeze": "Fridge (freeze)"}
const ADJ := {"fry": "Fried", "boil": "Boiled", "bake": "Roasted", "deepfry": "Deep-Fried",
	"grill": "Grilled", "microwave": "Microwaved", "toast": "Toasted"}
const BASE_TIME := {"fry": 7.0, "boil": 9.0, "bake": 11.0, "deepfry": 6.0, "grill": 7.5,
	"microwave": 4.0, "toast": 4.5, "chill": 6.0}
const BROWN := {"fry": 0.5, "boil": 0.1, "bake": 0.55, "deepfry": 0.8, "grill": 0.65,
	"microwave": 0.05, "toast": 0.6, "chill": 0.0}
const CAN_BURN := {"fry": true, "bake": true, "deepfry": true, "boil": false, "grill": true,
	"microwave": true, "toast": false, "chill": false}
const COLD := ["chill", "freeze"]
const TIME_MULT := {"chicken": 1.3, "chicken_breast": 1.2, "turkey": 1.3, "ribs": 1.4, "pork_belly": 1.3,
	"beef": 1.15, "potato": 1.3, "sweet_potato": 1.3, "rice": 1.2, "pumpkin": 1.3, "butternut": 1.3,
	"sausage": 1.15, "dough": 1.2, "cake_batter": 1.2, "corn": 1.1, "egg": 0.8, "shrimp": 0.7,
	"bread": 0.6, "toast": 0.6, "marshmallow": 0.5, "sugar": 0.8, "chocolate": 0.6, "frankfurter": 0.6}

## Ingredients with their own special cut (no slice/dice choice).
const CUT_MAX := {"egg": 1, "bread": 1, "bun": 1, "brioche_bun": 1, "hot_dog_bun": 1, "bagel": 1,
	"english_muffin": 1, "crumpet": 1, "croissant": 1, "baguette": 1, "dough": 1, "pasta_dough": 1,
	"pastry": 1, "puff_pastry": 1, "boiled_egg": 1, "toast": 1, "bread_loaf": 1, "tortilla": 1, "pita": 1,
	"naan": 1, "pizza": 1, "cake": 1, "cheesecake": 1, "tiramisu": 1, "quiche": 1, "pie": 1, "butter": 1,
	"brownies": 1, "flapjacks": 1, "waffle": 1, "coconut": 1, "pomegranate": 1, "lasagne_sheets": 1}
const CUT_WORDS := {
	"egg": ["", "Cracked"], "bread": ["", "Sliced"], "bun": ["", "Split"], "brioche_bun": ["", "Split"],
	"hot_dog_bun": ["", "Split"], "bagel": ["", "Split"], "english_muffin": ["", "Split"],
	"crumpet": ["", "Halved"], "croissant": ["", "Split"], "baguette": ["", "Sliced"], "dough": ["", "Rolled"],
	"pasta_dough": ["", "Cut"], "pastry": ["", "Rolled"], "puff_pastry": ["", "Cut"],
	"boiled_egg": ["", "Sliced"], "toast": ["", "Cut"], "bread_loaf": ["", "Sliced"],
	"tortilla": ["", "Cut"], "pita": ["", "Opened"], "naan": ["", "Torn"], "pizza": ["", "Sliced"],
	"cake": ["", "Sliced"], "cheesecake": ["", "Sliced"], "tiramisu": ["", "Sliced"], "quiche": ["", "Sliced"],
	"pie": ["", "Sliced"], "butter": ["", "Sliced"], "brownies": ["", "Cut"], "flapjacks": ["", "Cut"],
	"waffle": ["", "Cut"], "coconut": ["", "Cracked"], "pomegranate": ["", "Seeded"],
	"lasagne_sheets": ["", "Cut"],
	"cheese": ["", "Sliced", "Grated"], "parmesan": ["", "Shaved", "Grated"],
}
const DEFAULT_CUT_WORDS := ["", "Chopped", "Minced", "Puréed"]
const STYLE_WORDS := {"slice": "Sliced", "dice": "Diced", "free": "Hand-Cut", "wedge": "Wedged"}
const CUT_VERB := {"Chopped": "chop", "Minced": "mince", "Cracked": "crack", "Sliced": "slice",
	"Rolled": "roll flat", "Split": "split", "Cut": "cut", "Grated": "grate", "Shaved": "shave",
	"Diced": "dice", "Hand-Cut": "cut", "Opened": "open", "Torn": "tear", "Halved": "halve",
	"Seeded": "seed", "Wedged": "cut into wedges"}
const COAT_WORDS := {"crumb": "Breaded", "panko": "Panko-Crusted", "batter": "Battered", "flour": "Floured"}
## Coatings: id -> coat kind. Applied to meat/fish/veg/cheese in the mixing bowl.
const COATINGS := {"breadcrumbs": "crumb", "panko": "panko", "batter": "batter", "flour": "flour",
	"cornflour": "flour"}
const COAT_COLOR := {"crumb": "e0b060", "panko": "f2dca0", "batter": "f3e5ab", "flour": "f8f3e8"}

# [method, input specs, output id, index of input whose name flavours the output (-1 none)]
# Spec grammar: alternatives "a|b", each may carry /c1 (cut at least 1), /w (whole),
# /slice /dice /free (that cut style), /coat (breaded or battered); then optional
# ":fry,bake" (any of these methods), ":cooked" or ":raw".
# "#cat" matches a category, "*" matches any single ingredient.
const RULES := [
	# ---- mixing bowl
	["mix", ["flour", "sugar", "egg/c1", "butter", "milk"], "cake_batter", -1],
	["mix", ["flour", "sugar", "egg/c1", "oil", "milk|buttermilk"], "cake_batter", -1],
	["mix", ["flour", "sugar", "butter", "egg/c1"], "cookie_dough", -1],
	["mix", ["flour", "egg/c1", "milk|buttermilk"], "batter", -1],
	["mix", ["flour", "milk|buttermilk"], "batter", -1],
	["mix", ["flour", "yeast"], "dough", -1],
	["mix", ["flour", "butter"], "pastry", -1],
	["mix", ["flour", "egg/c1"], "pasta_dough", -1],
	["mix", ["mayo|mayonnaise", "garlic|garlic_powder"], "aioli", -1],
	["mix", ["egg/c1", "oil|olive_oil"], "mayo", -1],
	["mix", ["olive_oil|oil", "vinegar|balsamic|lemon|lime"], "vinaigrette", -1],
	["mix", ["butter", "garlic|garlic_powder"], "garlic_butter", -1],
	["mix", ["yogurt", "cucumber/c1"], "tzatziki", -1],
	["mix", ["butter|cream_cheese", "icing_sugar"], "frosting", -1],
	["mix", ["egg/c1"], "beaten_egg", -1],
	["mix", ["flour"], "dough", -1],
	["mix", ["ground_beef|pork_mince|lamb_mince", "breadcrumbs|egg/c1|panko"], "meatballs", -1],
	["mix", ["chickpeas", "parsley|cilantro|herbs|onion|garlic"], "falafel", -1],
	["mix", ["potato/c2|sweet_potato/c2", "egg/c1|flour"], "hash_browns", -1],
	["mix", ["ground_beef|pork_mince|lamb_mince"], "patty", -1],
	["mix", ["cream"], "whipped_cream", -1],
	["mix", ["tomato/c1|cherry_tomato/c1", "onion/c1|red_onion/c1"], "salsa", -1],
	["mix", ["avocado/c1", "lime|lemon"], "guacamole", -1],
	["mix", ["potato:boil", "butter|milk|cream"], "mashed_potato", -1],
	["mix", ["sweet_potato:boil", "butter|milk|cream"], "mashed_potato", 0],
	# ---- blender
	["blend", ["ice_cream", "milk", "coffee|brewed_coffee"], "frappe", -1],
	["blend", ["ice_cream", "milk", "*"], "milkshake", 2],
	["blend", ["ice_cream", "milk"], "milkshake", -1],
	["blend", ["basil|parsley|cilantro|kale", "garlic", "oil|olive_oil"], "pesto", -1],
	["blend", ["avocado", "lime|lemon"], "guacamole", -1],
	["blend", ["chickpeas", "tahini|lemon|garlic"], "hummus", -1],
	["blend", ["lemon|lime", "sugar"], "lemonade", -1],
	["blend", ["#fruit", "milk|yogurt|ice_cream|coconut_milk"], "smoothie", 0],
	["blend", ["potato:boil"], "mashed_potato", -1],
	["blend", ["tomato|canned_tomatoes|cherry_tomato"], "tomato_sauce", -1],
	["blend", ["chickpeas"], "hummus", -1],
	["blend", ["peanuts"], "peanut_butter", -1],
	["blend", ["#fruit"], "juice", 0],
	# ---- frying pan
	["fry", ["bread/c1|brioche_bun/c1", "beaten_egg"], "french_toast", -1],
	["fry", ["bread/c1", "cheese|mozzarella"], "grilled_cheese", -1],
	["fry", ["batter", "#fruit|chocolate"], "pancakes", 1],
	["fry", ["sugar|brown_sugar", "butter|cream"], "caramel", -1],
	["fry", ["corn", "butter|oil"], "popcorn", -1],
	["fry", ["egg/c1"], "fried_egg", -1],
	["fry", ["beaten_egg"], "scrambled_eggs", -1],
	["fry", ["batter"], "pancakes", -1],
	["fry", ["bread/c1|bread_loaf/c1|baguette/c1"], "toast", -1],
	["fry", ["sugar"], "caramel", -1],
	["fry", ["chocolate|white_chocolate"], "melted_chocolate", -1],
	["fry", ["potato/c2|sweet_potato/c2"], "hash_browns", -1],
	# ---- pot
	["boil", ["oats", "milk|coconut_milk"], "porridge", -1],
	["boil", ["milk", "chocolate|cocoa"], "hot_chocolate", -1],
	["boil", ["milk|cream", "egg/c1", "sugar"], "custard", -1],
	["boil", ["milk|cream", "cheese|parmesan"], "cheese_sauce", -1],
	["boil", ["broth", "flour|cornflour"], "gravy", -1],
	["boil", ["lentils", "*"], "dal", 1],
	["boil", ["lentils"], "dal", -1],
	["boil", ["rice"], "steamed_rice", -1],
	["boil", ["quinoa"], "cooked_quinoa", -1],
	["boil", ["couscous"], "cooked_couscous", -1],
	["boil", ["pasta"], "cooked_pasta", -1],
	["boil", ["pasta_dough/c1"], "cooked_pasta", -1],
	["boil", ["penne"], "cooked_penne", -1],
	["boil", ["macaroni"], "cooked_macaroni", -1],
	["boil", ["noodles"], "cooked_noodles", -1],
	["boil", ["rice_noodles"], "cooked_rice_noodles", -1],
	["boil", ["egg/w"], "boiled_egg", -1],
	["boil", ["egg/c1"], "poached_egg", -1],
	["boil", ["tea"], "brewed_tea", -1],
	["boil", ["coffee"], "brewed_coffee", -1],
	["boil", ["oats"], "porridge", -1],
	["boil", ["chocolate|white_chocolate"], "melted_chocolate", -1],
	["boil", ["sugar", "#fruit"], "jam", 1],
	# ---- oven
	["bake", ["dough", "tomato_sauce|tomato_paste", "cheese|mozzarella"], "pizza", -1],
	["bake", ["pastry|puff_pastry", "beaten_egg", "*"], "quiche", 2],
	["bake", ["pastry|puff_pastry", "beaten_egg"], "quiche", -1],
	["bake", ["puff_pastry|pastry", "sausage|pork_mince"], "sausage_roll", -1],
	["bake", ["dough|pastry", "#fruit|#meat|#fish|pumpkin|mushroom"], "pie", 1],
	["bake", ["cake_batter", "cocoa"], "brownies", -1],
	["bake", ["oats", "butter", "honey|golden_syrup|maple_syrup"], "flapjacks", -1],
	["bake", ["cake_batter", "*"], "cake", 1],
	["bake", ["cookie_dough", "*"], "cookies", 1],
	["bake", ["batter", "#fruit"], "muffins", 1],
	["bake", ["dough", "*"], "bread_loaf", 1],
	["bake", ["dough"], "bread_loaf", -1],
	["bake", ["cake_batter"], "cake", -1],
	["bake", ["cookie_dough"], "cookies", -1],
	["bake", ["batter"], "muffins", -1],
	["bake", ["bread/c1"], "toast", -1],
	["bake", ["potato/dice|potato/free"], "roast_potatoes", -1],
	# ---- deep fryer
	["deepfry", ["potato/slice"], "crisps", -1],
	["deepfry", ["potato/c1"], "fries", -1],
	["deepfry", ["sweet_potato/c1"], "sweet_potato_fries", -1],
	["deepfry", ["rice_paper|wonton_wrappers", "*"], "spring_rolls", 1],
	["deepfry", ["tortilla"], "tortilla_chips", -1],
	["deepfry", ["dough"], "donuts", -1],
	["deepfry", ["corn"], "popcorn", -1],
	# ---- grill
	["grill", ["#meat/c1|#fish/c1|halloumi/c1|tofu/c1", "#veg/c1", "#veg/c1"], "kebab", 0],
	["grill", ["#meat/c1|#fish/c1|halloumi/c1|tofu/c1", "#veg/c1"], "kebab", 0],
	["grill", ["bread/c1"], "toast", -1],
	# ---- microwave
	["microwave", ["cake_batter", "*"], "mug_cake", 1],
	["microwave", ["cake_batter"], "mug_cake", -1],
	["microwave", ["corn"], "popcorn", -1],
	["microwave", ["milk", "chocolate|cocoa"], "hot_chocolate", -1],
	["microwave", ["chocolate|white_chocolate"], "melted_chocolate", -1],
	["microwave", ["beaten_egg"], "scrambled_eggs", -1],
	["microwave", ["oats", "milk"], "porridge", -1],
	# ---- toaster
	["toast", ["bread/c1|baguette/c1|bread_loaf/c1"], "toast", -1],
	# ---- fridge
	["chill", ["oats", "milk|yogurt"], "overnight_oats", -1],
	["chill", ["gelatin", "*"], "jelly", 1],
	["chill", ["gelatin"], "jelly", -1],
	["chill", ["cream_cheese", "sugar|icing_sugar", "biscuits|crackers"], "cheesecake", -1],
	["chill", ["brewed_coffee", "biscuits", "cream_cheese|cream|whipped_cream"], "tiramisu", -1],
	["chill", ["melted_chocolate", "whipped_cream|cream"], "chocolate_mousse", -1],
	["chill", ["brewed_tea"], "iced_tea", -1],
	["chill", ["brewed_coffee", "milk"], "iced_coffee", -1],
	["freeze", ["cream", "sugar", "*"], "ice_cream", 2],
	["freeze", ["cream", "sugar|condensed_milk"], "ice_cream", -1],
	["freeze", ["yogurt", "*"], "frozen_yogurt", 1],
	["freeze", ["juice|smoothie|lemonade"], "ice_pop", 0],
]

# [name, specs]. "{} " in a name is replaced by the flavour of a flavoured leaf.
const RECIPES := [
	# Breakfast
	["Fried Egg on Toast", ["fried_egg", "toast"]],
	["Scrambled Eggs on Toast", ["scrambled_eggs", "toast"]],
	["Poached Egg on Toast", ["poached_egg", "toast"]],
	["Eggs Benedict", ["poached_egg", "english_muffin:toast,grill,bake|english_muffin/c1", "ham|bacon:cooked", "butter|mayonnaise|mayo"]],
	["Eggs Royale", ["poached_egg", "english_muffin|english_muffin/c1", "smoked_salmon"]],
	["Bacon & Eggs", ["bacon:fry,bake,grill", "fried_egg|scrambled_eggs|poached_egg"]],
	["Full Breakfast", ["fried_egg|scrambled_eggs", "bacon:cooked", "sausage:cooked", "toast"]],
	["Full English", ["fried_egg|scrambled_eggs|poached_egg", "bacon:cooked", "sausage:cooked", "beans", "toast", "mushroom|tomato:cooked"]],
	["Pancake Stack", ["pancakes", "maple_syrup|honey|golden_syrup"]],
	["Pancakes & Cream", ["pancakes", "whipped_cream"]],
	["Pancakes & Bacon", ["pancakes", "bacon:cooked", "maple_syrup"]],
	["Chocolate Banana Pancakes", ["pancakes", "banana", "chocolate|melted_chocolate|choc_spread"]],
	["{} Pancakes", ["pancakes"]],
	["Waffles & Syrup", ["waffle:toast,microwave,bake", "maple_syrup|golden_syrup|honey"]],
	["Berry Waffles", ["waffle:cooked", "strawberry|blueberry|raspberry", "whipped_cream|yogurt|maple_syrup"]],
	["Chicken & Waffles", ["waffle:cooked", "chicken/coat|chicken_breast/coat:deepfry,fry", "maple_syrup|hot_sauce"]],
	["French Toast", ["french_toast"]],
	["French Toast & Syrup", ["french_toast", "maple_syrup|honey"]],
	["Porridge", ["porridge"]],
	["Honey Banana Porridge", ["porridge", "banana", "honey"]],
	["Berry Porridge", ["porridge", "strawberry|blueberry|raspberry"]],
	["Overnight Oats", ["overnight_oats"]],
	["Berry Overnight Oats", ["overnight_oats", "strawberry|blueberry|raspberry|banana"]],
	["Granola Bowl", ["granola", "yogurt|milk"]],
	["Cereal & Milk", ["cereal", "milk"]],
	["Avocado Toast", ["toast", "avocado/c1"]],
	["Avocado Egg Toast", ["toast", "avocado/c1", "fried_egg|poached_egg"]],
	["Smashed Avo & Feta", ["toast", "avocado/c1", "feta", "chili_flakes|chili"]],
	["Cheese Omelette", ["scrambled_eggs", "cheese"]],
	["Ham & Cheese Omelette", ["scrambled_eggs", "ham", "cheese"]],
	["Veggie Omelette", ["scrambled_eggs", "bell_pepper|green_pepper|mushroom|spinach", "onion|tomato|scallion"]],
	["Shakshuka", ["egg|poached_egg|fried_egg", "canned_tomatoes|tomato_sauce:cooked", "bell_pepper|onion|chili:cooked", "cumin|paprika"]],
	["Huevos Rancheros", ["fried_egg", "tortilla", "salsa", "black_beans|beans"]],
	["Yogurt Parfait", ["yogurt", "#fruit", "oats|granola"]],
	["Breakfast Burrito", ["tortilla", "scrambled_eggs", "bacon|sausage|chorizo:cooked", "cheese"]],
	["Egg Sandwich", ["bread/c1|bun|toast", "fried_egg"]],
	["Bacon Bagel", ["bagel/c1", "bacon:cooked"]],
	["Bagel & Cream Cheese", ["bagel/c1|bagel", "cream_cheese"]],
	["Lox Bagel", ["bagel/c1", "cream_cheese", "smoked_salmon"]],
	["Croissant & Jam", ["croissant", "jam|butter"]],
	["Ham & Cheese Croissant", ["croissant/c1", "ham", "cheese|brie"]],
	["Buttered Crumpets", ["crumpet:toast,grill", "butter|honey|jam"]],
	["Toast & Jam", ["toast", "jam"]],
	["Toast & Butter", ["toast", "butter"]],
	["Beans on Toast", ["beans:cooked", "toast"]],
	["Cheese on Toast", ["toast", "cheese:bake,grill,microwave"]],
	["Peanut Butter & Jelly", ["bread/c1|toast", "peanut_butter", "jam"]],
	["Chocolate Spread Toast", ["toast", "choc_spread"]],
	["Cinnamon Toast", ["toast", "cinnamon", "sugar|butter|honey"]],
	["Peanut Butter Banana Toast", ["toast", "peanut_butter", "banana"]],
	["Hash Browns", ["hash_browns"]],
	["Hash Brown Stack", ["hash_browns", "fried_egg|poached_egg", "bacon:cooked"]],
	# Sandwiches & burgers
	["Grilled Cheese", ["grilled_cheese"]],
	["Ham & Cheese Toastie", ["grilled_cheese", "ham"]],
	["Tomato Soup & Grilled Cheese", ["grilled_cheese", "tomato_sauce:boil"]],
	["BLT", ["bread/c1|toast", "bacon:cooked", "lettuce", "tomato/c1"]],
	["Club Sandwich", ["toast", "chicken|chicken_breast|turkey:cooked", "bacon:cooked", "lettuce", "tomato/c1"]],
	["Turkey Sandwich", ["bread/c1|toast", "turkey_slices|turkey:cooked", "lettuce|cheese|mayonnaise"]],
	["Tuna Mayo Sandwich", ["bread/c1|toast|baguette/c1", "canned_tuna", "mayo|mayonnaise"]],
	["Tuna Melt", ["bread/c1|toast", "canned_tuna", "cheese:bake,grill,fry,microwave"]],
	["Hamburger", ["bun|brioche_bun", "patty:fry,bake,grill"]],
	["Cheeseburger", ["bun|brioche_bun", "patty:fry,bake,grill", "cheese"]],
	["Double Cheeseburger", ["bun|brioche_bun", "patty:fry,bake,grill", "patty:fry,bake,grill", "cheese"]],
	["Bacon Cheeseburger", ["bun|brioche_bun", "patty:fry,bake,grill", "bacon:cooked", "cheese"]],
	["Deluxe Burger", ["bun|brioche_bun", "patty:fry,bake,grill", "cheese", "lettuce", "tomato/c1", "onion/c1|red_onion/c1"]],
	["Classic Burger", ["bun|brioche_bun", "patty:fry,bake,grill", "lettuce", "tomato/c1", "pickles", "ketchup|mustard|mayonnaise"]],
	["BBQ Burger", ["bun|brioche_bun", "patty:fry,bake,grill", "bbq_sauce", "onion/c1|red_onion/c1"]],
	["Blue Cheese Burger", ["bun|brioche_bun", "patty:fry,grill", "blue_cheese"]],
	["Chicken Burger", ["bun|brioche_bun", "chicken|chicken_breast:fry,deepfry,bake,grill"]],
	["Crispy Chicken Burger", ["bun|brioche_bun", "chicken/coat|chicken_breast/coat:fry,deepfry", "lettuce|mayonnaise|mayo"]],
	["Halloumi Burger", ["bun|brioche_bun", "halloumi:grill,fry"]],
	["Falafel Burger", ["bun|brioche_bun", "falafel:cooked"]],
	["Fish Burger", ["bun|brioche_bun|bread/c1", "white_fish|salmon:cooked"]],
	["Pulled Pork Bun", ["bun|brioche_bun", "pork_belly|pork_chop/c1:bake,grill,boil", "bbq_sauce"]],
	["Hot Dog", ["hot_dog_bun", "frankfurter|sausage:cooked"]],
	["Loaded Hot Dog", ["hot_dog_bun", "frankfurter|sausage:cooked", "onion/c1|red_onion/c1", "ketchup|mustard"]],
	["Chili Dog", ["hot_dog_bun", "frankfurter|sausage:cooked", "ground_beef:cooked", "cheese|chili"]],
	["Chicago Dog", ["hot_dog_bun", "frankfurter:cooked", "pickles", "tomato/c1", "mustard", "onion/c1"]],
	["Bratwurst Roll", ["hot_dog_bun|baguette/c1", "sausage:grill,fry", "onion:cooked", "mustard"]],
	["Corn Dog", ["frankfurter/coat|sausage/coat:deepfry"]],
	["Egg Mayo Sandwich", ["bread/c1|toast", "boiled_egg/c1", "mayo|mayonnaise"]],
	["Meatball Sub", ["bun|bread/c1|baguette/c1|hot_dog_bun", "meatballs:cooked", "tomato_sauce"]],
	["Ham Sandwich", ["bread/c1|baguette/c1", "ham", "butter|mustard|mayo|mayonnaise"]],
	["Cheese & Pickle Sandwich", ["bread/c1", "cheese", "pickles"]],
	["Caprese Baguette", ["baguette/c1", "mozzarella", "tomato/c1", "basil|pesto"]],
	["Banh Mi", ["baguette/c1", "pork_belly|pork_chop|chicken_breast:cooked", "carrot/c1|cucumber/c1", "cilantro|sriracha|mayonnaise"]],
	["Cuban Sandwich", ["bread/c1|baguette/c1", "ham", "pork_chop|pork_belly:cooked", "pickles", "cheese"]],
	["Reuben", ["bread/c1|toast", "beef/c1:cooked", "cabbage/c1|red_cabbage/c1", "cheese"]],
	["Philly Cheesesteak", ["baguette/c1|hot_dog_bun|bun", "beef/c1:fry,grill", "onion/c1:cooked", "cheese|cheese_sauce"]],
	["Gyro", ["pita|pita/c1", "lamb_chop|lamb_mince|chicken_breast:cooked", "tzatziki", "tomato/c1|onion/c1"]],
	["Pita Pocket", ["pita/c1", "falafel:cooked", "hummus|tahini"]],
	["Chicken Shawarma", ["pita|naan|tortilla", "chicken|chicken_breast/c1:cooked", "garlic_butter|aioli|tzatziki"]],
	# Mexican
	["Beef Tacos", ["tortilla|taco_shell", "ground_beef:fry"]],
	["Crunchy Tacos", ["taco_shell", "ground_beef|chicken/c1:cooked", "lettuce|cheese"]],
	["Chicken Tacos", ["tortilla|taco_shell", "chicken|chicken_breast/c1:fry,grill"]],
	["Fish Tacos", ["tortilla|taco_shell", "white_fish:fry,deepfry,grill"]],
	["Shrimp Tacos", ["tortilla|taco_shell", "shrimp:cooked", "lime|cilantro|avocado"]],
	["Pork Carnitas", ["tortilla", "pork_belly|pork_chop/c1:cooked", "lime|cilantro|onion/c1"]],
	["Burrito", ["tortilla", "steamed_rice", "beans|black_beans|kidney_beans", "ground_beef|chicken:cooked"]],
	["Burrito Bowl", ["steamed_rice", "black_beans|kidney_beans", "chicken|chicken_breast|ground_beef:cooked", "salsa|guacamole|sour_cream"]],
	["Quesadilla", ["tortilla:fry", "cheese:fry"]],
	["Chicken Quesadilla", ["tortilla:fry", "cheese:fry", "chicken|chicken_breast:fry"]],
	["Enchiladas", ["tortilla:bake", "chicken|ground_beef:bake", "tomato_sauce|salsa", "cheese:bake"]],
	["Nachos", ["tortilla_chips", "cheese"]],
	["Loaded Nachos", ["tortilla_chips", "cheese", "salsa", "guacamole"]],
	["Nachos Supreme", ["tortilla_chips", "cheese|cheese_sauce", "jalapeno", "sour_cream"]],
	["Chips & Guac", ["tortilla_chips", "guacamole"]],
	["Chips & Salsa", ["tortilla_chips", "salsa"]],
	["Fajitas", ["tortilla", "chicken/c1|beef/c1|chicken_breast/c1:fry,grill", "bell_pepper/c1|green_pepper/c1:fry,grill", "onion/c1:fry,grill"]],
	["Chili con Carne", ["ground_beef:cooked", "beans|kidney_beans", "tomato_sauce|tomato/c1|canned_tomatoes", "chili|chili_flakes"]],
	["Mexican Street Corn", ["corn:grill,boil", "mayonnaise|mayo|sour_cream", "cheese|feta|parmesan"]],
	# Italian
	["Spaghetti Bolognese", ["cooked_pasta", "tomato_sauce|canned_tomatoes", "ground_beef:cooked"]],
	["Spaghetti & Meatballs", ["cooked_pasta", "meatballs:cooked", "tomato_sauce"]],
	["Pasta Pomodoro", ["cooked_pasta|cooked_penne", "tomato_sauce"]],
	["Penne Arrabbiata", ["cooked_penne", "tomato_sauce|canned_tomatoes", "chili|chili_flakes"]],
	["Mac & Cheese", ["cooked_macaroni|cooked_pasta", "cheese|cheese_sauce", "milk|cream|cheese_sauce"]],
	["Mac & Cheese Bites", ["cooked_macaroni/coat:deepfry", "cheese"]],
	["Baked Mac & Cheese", ["cooked_macaroni|cooked_pasta:bake", "cheese|cheese_sauce:bake", "breadcrumbs|panko"]],
	["Carbonara", ["cooked_pasta", "bacon:cooked", "egg|beaten_egg|scrambled_eggs", "parmesan"]],
	["Pesto Pasta", ["cooked_pasta|cooked_penne", "pesto"]],
	["Fettuccine Alfredo", ["cooked_pasta", "cream", "parmesan"]],
	["Chicken Alfredo", ["cooked_pasta|cooked_penne", "cream|cheese_sauce", "parmesan", "chicken|chicken_breast:cooked"]],
	["Garlic Butter Pasta", ["cooked_pasta", "garlic|garlic_butter", "butter|garlic_butter"]],
	["Puttanesca", ["cooked_pasta", "tomato_sauce|canned_tomatoes", "olives", "capers|anchovies"]],
	["Seafood Linguine", ["cooked_pasta", "shrimp|mussels|squid|crab:cooked", "garlic|tomato_sauce"]],
	["Pasta Salad", ["cooked_penne|cooked_macaroni", "tomato/c1|cherry_tomato|cucumber/c1", "vinaigrette|mayonnaise|pesto"]],
	["Lasagna", ["cooked_pasta|lasagne_sheets:bake", "tomato_sauce:bake", "ground_beef:bake", "cheese|mozzarella|cheese_sauce:bake"]],
	["Cheese Pizza", ["pizza"]],
	["Margherita Pizza", ["pizza", "basil"]],
	["Pepperoni Pizza", ["pizza", "pepperoni"]],
	["Hawaiian Pizza", ["pizza", "ham", "pineapple"]],
	["Meat Lovers Pizza", ["pizza", "pepperoni", "bacon", "sausage|salami|chorizo"]],
	["Veggie Pizza", ["pizza", "bell_pepper|green_pepper", "mushroom", "onion|red_onion"]],
	["BBQ Chicken Pizza", ["pizza", "chicken|chicken_breast:cooked", "bbq_sauce"]],
	["Diavola Pizza", ["pizza", "salami|pepperoni|chorizo", "chili|chili_flakes|jalapeno"]],
	["Prosciutto Pizza", ["pizza", "prosciutto"]],
	["Pita Pizza", ["pita:bake,grill", "tomato_sauce|tomato_paste", "cheese|mozzarella"]],
	["Caprese Salad", ["tomato/c1|cherry_tomato", "mozzarella", "basil"]],
	["Bruschetta", ["toast", "tomato/c1|cherry_tomato", "basil|garlic|balsamic"]],
	["Garlic Bread", ["toast|bread_loaf|baguette:bake,grill", "garlic|garlic_butter", "butter|garlic_butter"]],
	["Mushroom Risotto", ["steamed_rice", "mushroom:cooked", "parmesan|cheese"]],
	["Gnocchi-ish Potato Bites", ["potato/dice:boil", "butter|pesto", "parmesan|herbs"]],
	["Chicken Parmigiana", ["chicken_breast/coat|chicken/coat:fry,bake,deepfry", "tomato_sauce", "mozzarella|cheese"]],
	["Arancini", ["steamed_rice/coat:deepfry"]],
	# Asian
	["Egg Fried Rice", ["steamed_rice:fry", "egg|beaten_egg|scrambled_eggs|fried_egg"]],
	["Chicken Fried Rice", ["steamed_rice:fry", "chicken|chicken_breast:fry", "scallion|onion|carrot|peas"]],
	["Shrimp Fried Rice", ["steamed_rice:fry", "shrimp:fry", "egg|beaten_egg|scrambled_eggs|peas"]],
	["Kimchi-ish Fried Rice", ["steamed_rice:fry", "cabbage|red_cabbage:fry", "gochujang"]],
	["Teriyaki Chicken", ["chicken|chicken_breast:fry,bake,grill", "soy_sauce|teriyaki", "honey|teriyaki"]],
	["Teriyaki Salmon", ["salmon:fry,bake,grill", "teriyaki|soy_sauce"]],
	["Teriyaki Rice Bowl", ["steamed_rice", "chicken|chicken_breast:cooked", "soy_sauce|teriyaki", "honey|teriyaki"]],
	["Chicken Stir-Fry", ["chicken|chicken_breast/c1:fry", "bell_pepper|broccoli|carrot|cabbage|bok_choy:fry", "soy_sauce|hoisin|teriyaki"]],
	["Beef & Broccoli", ["beef/c1:fry", "broccoli:cooked", "soy_sauce|hoisin"]],
	["Veggie Stir-Fry", ["#veg:fry", "#veg:fry", "#veg:fry", "soy_sauce|hoisin|teriyaki"]],
	["Chow Mein", ["cooked_noodles:fry", "cabbage|carrot|bell_pepper|bok_choy:fry", "soy_sauce"]],
	["Pad Thai", ["cooked_rice_noodles|cooked_noodles:fry", "shrimp|chicken|tofu:fry", "peanut_butter|peanuts", "egg|beaten_egg|scrambled_eggs"]],
	["Singapore Noodles", ["cooked_rice_noodles:fry", "shrimp|chicken|pork_mince:fry", "curry_powder"]],
	["Ramen", ["cooked_noodles", "broth", "boiled_egg"]],
	["Chicken Ramen", ["cooked_noodles", "broth", "chicken|chicken_breast:cooked"]],
	["Miso Ramen", ["cooked_noodles", "broth", "miso"]],
	["Tonkotsu Ramen", ["cooked_noodles", "broth", "pork_belly:cooked", "boiled_egg|scallion"]],
	["Pho", ["cooked_rice_noodles", "broth", "beef/c1|chicken/c1", "basil|cilantro|mint|lime"]],
	["Miso Soup", ["miso", "broth|tofu", "tofu|scallion|nori"]],
	["Chicken Curry", ["chicken|chicken_breast:cooked", "curry_powder|curry_paste|garam_masala"]],
	["Butter Chicken", ["chicken|chicken_breast:cooked", "butter", "cream|yogurt", "tomato_sauce|canned_tomatoes|garam_masala"]],
	["Tikka Masala", ["chicken|chicken_breast/c1:grill,bake,fry", "yogurt|cream", "garam_masala|curry_powder", "tomato_sauce|canned_tomatoes"]],
	["Thai Green Curry", ["chicken|shrimp|tofu:cooked", "curry_paste", "coconut_milk"]],
	["Coconut Curry", ["#meat|#fish|tofu:cooked", "curry_powder|curry_paste", "coconut_milk"]],
	["Vegetable Curry", ["#veg:cooked", "#veg:cooked", "curry_powder|curry_paste|garam_masala"]],
	["Chickpea Curry", ["chickpeas:cooked", "curry_powder|curry_paste|garam_masala", "coconut_milk|canned_tomatoes|tomato_sauce"]],
	["Dal", ["dal"]],
	["Dal & Rice", ["dal", "steamed_rice"]],
	["Curry & Naan", ["naan", "chicken|lamb_chop|chickpeas:cooked", "curry_powder|curry_paste|garam_masala"]],
	["Salmon Sushi Roll", ["nori", "steamed_rice", "salmon/c1:raw"]],
	["Tuna Sushi Roll", ["nori", "steamed_rice", "tuna/c1:raw"]],
	["California Roll", ["nori", "steamed_rice", "crab", "avocado/c1|cucumber/c1"]],
	["Veggie Sushi Roll", ["nori", "steamed_rice", "cucumber/c1|avocado/c1|carrot/c1"]],
	["Sashimi", ["salmon/c1|tuna/c1:raw", "soy_sauce"]],
	["Poke Bowl", ["steamed_rice", "salmon/c1|tuna/c1:raw", "avocado/c1", "soy_sauce"]],
	["Bibimbap", ["steamed_rice", "fried_egg", "spinach|carrot", "beef|ground_beef:cooked"]],
	["Korean Fried Chicken", ["chicken/coat|chicken_wings/coat:deepfry", "gochujang|sweet_chili|soy_sauce"]],
	["Mapo Tofu", ["tofu:cooked", "ground_beef|pork_mince:cooked", "chili|chili_flakes"]],
	["Shrimp Tempura", ["shrimp/coat:deepfry"]],
	["Vegetable Tempura", ["#veg/coat:deepfry", "#veg/coat:deepfry"]],
	["Garlic Butter Shrimp", ["shrimp:fry,grill", "garlic|garlic_butter", "butter|garlic_butter"]],
	["Sweet & Sour Chicken", ["chicken|chicken_breast:deepfry,fry", "pineapple", "ketchup"]],
	["Sweet Chili Chicken", ["chicken|chicken_breast:cooked", "sweet_chili"]],
	["Chicken Katsu", ["chicken_breast/coat|chicken/coat:deepfry,fry", "steamed_rice", "curry_powder|curry_paste"]],
	["Tonkatsu", ["pork_chop/coat:deepfry,fry", "cabbage/c1|steamed_rice"]],
	["Dumplings", ["dough|wonton_wrappers:boil", "ground_beef|shrimp|pork_mince:boil"]],
	["Potstickers", ["dough|wonton_wrappers:fry", "ground_beef|shrimp|pork_mince:fry"]],
	["Spring Rolls", ["spring_rolls"]],
	["Fresh Summer Rolls", ["rice_paper", "shrimp:cooked", "lettuce|mint|carrot/c1"]],
	["Crispy Duck Pancakes", ["duck:bake,fry", "hoisin", "pancakes|tortilla", "cucumber/c1|scallion"]],
	["Char Siu Pork", ["pork_belly|pork_chop:bake,grill", "hoisin|honey"]],
	["Tofu Stir-Fry", ["tofu:fry", "#veg:fry", "soy_sauce|hoisin|teriyaki"]],
	["Salt & Pepper Squid", ["squid/coat:deepfry", "salt|black_pepper"]],
	# Mains
	["Steak & Chips", ["beef:fry,bake,grill", "fries"]],
	["Steak & Mash", ["beef:cooked", "mashed_potato"]],
	["Steak & Eggs", ["beef:cooked", "fried_egg|poached_egg"]],
	["Steak with Garlic Butter", ["beef:fry,grill", "garlic_butter"]],
	["Surf & Turf", ["beef:cooked", "shrimp|crab:cooked"]],
	["Fish & Chips", ["white_fish/coat:deepfry", "fries"]],
	["Fish Fingers", ["white_fish/c1/coat:deepfry,fry,bake"]],
	["Fish Finger Sandwich", ["bread/c1|toast|bun", "white_fish/c1/coat:cooked", "ketchup|mayonnaise|mayo"]],
	["Fried Chicken", ["chicken/coat|chicken_breast/coat|chicken_wings/coat:deepfry"]],
	["Chicken Strips", ["chicken_breast/slice/coat:deepfry,fry,bake"]],
	["Chicken Nuggets", ["chicken/c1/coat|chicken_breast/c1/coat:deepfry,fry,bake"]],
	["Nuggets & Fries", ["chicken/c1/coat|chicken_breast/c1/coat:cooked", "fries"]],
	["Chicken Schnitzel", ["chicken_breast/coat|pork_chop/coat:fry"]],
	["Popcorn Shrimp", ["shrimp/c1/coat:deepfry"]],
	["Onion Rings", ["onion/slice/coat|red_onion/slice/coat:deepfry"]],
	["Mozzarella Sticks", ["mozzarella/c1/coat|cheese/c1/coat|halloumi/c1/coat:deepfry"]],
	["Buffalo Wings", ["chicken_wings:deepfry,bake,grill", "hot_sauce|sriracha"]],
	["BBQ Wings", ["chicken_wings:cooked", "bbq_sauce"]],
	["Honey Garlic Wings", ["chicken_wings:cooked", "honey", "garlic|garlic_powder"]],
	["Wings & Ranch", ["chicken_wings:cooked", "ranch"]],
	["BBQ Ribs", ["ribs:bake,grill", "bbq_sauce|honey"]],
	["Roast Chicken", ["chicken:bake"]],
	["Grilled Chicken Breast", ["chicken_breast:grill"]],
	["Lemon Herb Chicken", ["chicken|chicken_breast:cooked", "lemon", "herbs|rosemary|oregano|parsley"]],
	["Cajun Chicken", ["chicken|chicken_breast:cooked", "cajun"]],
	["Roast Dinner", ["chicken|beef|turkey|pork_chop:bake", "potato|roast_potatoes:bake", "carrot|peas|broccoli|green_beans:cooked"]],
	["Sunday Roast", ["chicken|beef|turkey|lamb_chop:bake", "roast_potatoes|potato:bake", "gravy"]],
	["Roast Turkey", ["turkey:bake"]],
	["Pork Chop & Apple", ["pork_chop:cooked", "apple|green_apple"]],
	["Crispy Pork Belly", ["pork_belly:bake,deepfry,grill"]],
	["Lamb Chops & Mint", ["lamb_chop:cooked", "mint"]],
	["Lamb Kofta", ["lamb_mince:grill,fry", "tzatziki|yogurt|mint"]],
	["Duck à l'Orange", ["duck:cooked", "orange"]],
	["Honey Glazed Salmon", ["salmon:cooked", "honey"]],
	["Lemon Herb Fish", ["white_fish|salmon:cooked", "lemon", "herbs|basil|parsley"]],
	["Seared Tuna", ["tuna:fry,grill", "sesame_seeds|soy_sauce"]],
	["Moules Frites", ["mussels:boil", "fries"]],
	["Garlic Mussels", ["mussels:boil", "garlic|garlic_butter", "cream|butter|garlic_butter"]],
	["Crab Cakes", ["crab/coat:fry,deepfry"]],
	["Bangers & Mash", ["sausage:cooked", "mashed_potato"]],
	["Bangers, Mash & Gravy", ["sausage:cooked", "mashed_potato", "gravy"]],
	["Toad in the Hole", ["sausage:bake", "batter:bake"]],
	["Sausage Roll", ["sausage_roll"]],
	["Shepherd's Pie", ["ground_beef|lamb_mince:bake", "mashed_potato:bake"]],
	["Cottage Pie", ["ground_beef:bake", "mashed_potato:bake", "carrot|peas:bake"]],
	["Beef Stew", ["beef:boil", "potato:boil", "carrot:boil"]],
	["Irish Stew", ["lamb_chop|lamb_mince:boil", "potato:boil", "onion|carrot|leek:boil"]],
	["Chicken Pot Pie", ["pastry|puff_pastry:bake", "chicken|chicken_breast:bake", "peas|carrot|mushroom:bake"]],
	["Quiche", ["quiche"]],
	["Quiche Lorraine", ["quiche", "bacon|ham:cooked"]],
	["Baked Potato", ["potato/w:bake,microwave"]],
	["Loaded Baked Potato", ["potato/w:bake,microwave", "cheese", "bacon:cooked"]],
	["Jacket Potato & Beans", ["potato/w:bake,microwave", "beans", "cheese|butter"]],
	["Tuna Jacket Potato", ["potato/w:bake,microwave", "canned_tuna", "mayo|mayonnaise|sweetcorn"]],
	["Baked Sweet Potato", ["sweet_potato/w:bake,microwave"]],
	["Roast Potatoes", ["roast_potatoes"]],
	["Patatas Bravas", ["roast_potatoes|potato/dice:deepfry,fry", "tomato_sauce|paprika|hot_sauce", "aioli|mayonnaise|mayo"]],
	["Ratatouille", ["zucchini:cooked", "eggplant:cooked", "tomato:cooked", "bell_pepper:cooked"]],
	["Stuffed Peppers", ["bell_pepper|green_pepper|yellow_pepper/w:bake", "steamed_rice|ground_beef|cooked_couscous"]],
	["Stuffed Mushrooms", ["mushroom/w:bake,grill", "cheese|cream_cheese|goat_cheese|garlic_butter"]],
	["Eggplant Parmigiana", ["eggplant/slice:bake,fry", "tomato_sauce", "mozzarella|parmesan"]],
	["Chicken & Rice", ["chicken|chicken_breast:cooked", "steamed_rice"]],
	["Jambalaya", ["steamed_rice", "chorizo|sausage:cooked", "shrimp|chicken:cooked", "cajun|paprika"]],
	["Paella", ["steamed_rice", "shrimp|mussels|squid:cooked", "chorizo|chicken:cooked", "turmeric|paprika"]],
	["Halloumi & Veg", ["halloumi:grill,fry", "#veg:grill,bake"]],
	["Kebab", ["kebab"]],
	["{} Kebab Wrap", ["kebab", "pita|tortilla|naan"]],
	["Falafel Plate", ["falafel:cooked", "hummus|tahini|tzatziki"]],
	["Crispy Fries", ["fries", "salt"]],
	["Cheesy Fries", ["fries", "cheese|cheese_sauce"]],
	["Chili Cheese Fries", ["fries", "ground_beef:cooked", "cheese|cheese_sauce"]],
	["Poutine", ["fries", "gravy", "cheese|mozzarella"]],
	["Fries & Ketchup", ["fries", "ketchup"]],
	["Sweet Potato Fries", ["sweet_potato_fries"]],
	["Chips & Dip", ["crisps", "salsa|guacamole|hummus|mayo|sour_cream|ranch"]],
	["Grilled Corn", ["corn:grill"]],
	["Corn on the Cob", ["corn:boil", "butter"]],
	["Charcuterie Board", ["salami|prosciutto|ham", "cheese|brie|blue_cheese|goat_cheese", "crackers|baguette|bread", "grapes|olives|pickles"]],
	["Cheese & Crackers", ["crackers", "cheese|brie|blue_cheese|goat_cheese|cream_cheese"]],
	["Popcorn", ["popcorn"]],
	["Caramel Popcorn", ["popcorn", "caramel"]],
	["Toasted Nuts", ["peanuts|almonds|walnuts|cashews:toast,bake,fry"]],
	["Edamame-ish Peas", ["peas:boil", "salt"]],
	# Soups & salads
	["Tomato Soup", ["tomato_sauce|canned_tomatoes:boil"]],
	["Cream of Tomato Soup", ["tomato_sauce|canned_tomatoes:boil", "cream"]],
	["Pumpkin Soup", ["pumpkin|butternut/c3:boil"]],
	["Butternut Squash Soup", ["butternut:boil", "cream|coconut_milk"]],
	["Chicken Noodle Soup", ["chicken|chicken_breast:boil", "cooked_noodles", "carrot|onion|celery:boil"]],
	["Mushroom Soup", ["mushroom:boil", "cream"]],
	["Leek & Potato Soup", ["leek:boil", "potato:boil"]],
	["Broccoli Cheddar Soup", ["broccoli:boil", "cheese|cheese_sauce"]],
	["Pea Soup", ["peas:boil", "mint|ham"]],
	["Lentil Soup", ["lentils:boil", "carrot|onion|celery:boil"]],
	["Corn Chowder", ["corn|sweetcorn:boil", "potato:boil", "milk|cream"]],
	["Clam-ish Chowder", ["mussels|crab|white_fish:boil", "potato:boil", "milk|cream"]],
	["French Onion Soup", ["onion:boil", "broth", "toast|baguette", "cheese"]],
	["Borscht", ["beetroot:boil", "sour_cream|broth"]],
	["Minestrone", ["cooked_pasta|cooked_macaroni", "tomato|tomato_sauce|canned_tomatoes:boil", "beans|kidney_beans"]],
	["Gazpacho", ["tomato/c3|canned_tomatoes", "cucumber/c3|bell_pepper/c3"]],
	["Garden Salad", ["lettuce", "tomato/c1|cherry_tomato", "cucumber/c1"]],
	["Caesar Salad", ["lettuce", "toast", "parmesan"]],
	["Chicken Caesar Salad", ["lettuce", "toast", "parmesan", "chicken|chicken_breast:cooked"]],
	["Greek Salad", ["tomato/c1|cherry_tomato", "cucumber/c1", "onion/c1|red_onion/c1", "feta|cheese"]],
	["Cobb Salad", ["lettuce", "chicken|chicken_breast|turkey:cooked", "bacon:cooked", "boiled_egg/c1", "avocado/c1|blue_cheese"]],
	["Niçoise Salad", ["lettuce|green_beans", "tuna|canned_tuna", "boiled_egg/c1", "olives|potato:boil"]],
	["Waldorf Salad", ["apple/c1|green_apple/c1", "celery/c1", "walnuts", "mayo|mayonnaise"]],
	["Caprese Stack", ["tomato/slice", "mozzarella/slice", "basil|balsamic|pesto"]],
	["Beetroot & Goat Cheese Salad", ["beetroot:cooked", "goat_cheese", "walnuts|spinach|lettuce"]],
	["Halloumi Salad", ["halloumi:grill,fry", "lettuce|spinach|kale", "tomato/c1|cherry_tomato|pomegranate/c1"]],
	["Kale Salad", ["kale/c1", "vinaigrette|olive_oil|lemon"]],
	["Quinoa Salad", ["cooked_quinoa", "#veg/c1", "#veg/c1"]],
	["Couscous Salad", ["cooked_couscous", "#veg/c1", "lemon|olive_oil|mint|parsley"]],
	["Tabbouleh", ["cooked_couscous|cooked_quinoa", "parsley|mint", "tomato/c1|cucumber/c1"]],
	["Fruit Salad", ["#fruit/c1", "#fruit/c1", "#fruit/c1"]],
	["Watermelon Feta Salad", ["watermelon/c1", "feta", "mint"]],
	["Coleslaw", ["cabbage|red_cabbage/c1", "carrot/c1", "mayo|mayonnaise"]],
	["Potato Salad", ["potato:boil", "mayo|mayonnaise"]],
	["Egg Salad", ["boiled_egg/c1", "mayo|mayonnaise"]],
	["Tuna Salad", ["canned_tuna", "mayo|mayonnaise", "celery/c1|onion/c1|lettuce|sweetcorn"]],
	["Hummus & Veggies", ["hummus", "carrot/c1|cucumber/c1|bell_pepper/c1|celery/c1"]],
	["Tzatziki & Pita", ["tzatziki", "pita|pita/c1|naan"]],
	["Guac & Veggies", ["guacamole", "carrot/c1|cucumber/c1|celery/c1|bell_pepper/c1"]],
	# Bakery & desserts
	["{} Pie", ["pie"]],
	["Pie & Custard", ["pie", "custard"]],
	["Pie & Ice Cream", ["pie", "ice_cream"]],
	["{} Cake", ["cake"]],
	["Frosted {} Cake", ["cake", "frosting"]],
	["Birthday Cake", ["cake", "sprinkles|whipped_cream"]],
	["Carrot Cake", ["cake", "carrot/c1", "frosting|cream_cheese"]],
	["Cheesecake", ["cheesecake"]],
	["Berry Cheesecake", ["cheesecake", "strawberry|blueberry|raspberry|cherry|jam"]],
	["Tiramisu", ["tiramisu"]],
	["Brownies", ["brownies"]],
	["Brownie Sundae", ["brownies", "ice_cream"]],
	["Flapjacks", ["flapjacks"]],
	["Mug Cake", ["mug_cake"]],
	["{} Cookies", ["cookies"]],
	["Cookies & Milk", ["cookies", "milk"]],
	["Ice Cream Sandwich", ["cookies|biscuits", "ice_cream"]],
	["{} Muffins", ["muffins"]],
	["Cupcakes", ["muffins", "frosting|sprinkles"]],
	["{} Bread", ["bread_loaf"]],
	["Donuts", ["donuts"]],
	["Glazed Donuts", ["donuts", "sugar|icing_sugar|sprinkles|melted_chocolate"]],
	["Churros", ["donuts", "cinnamon"]],
	["Churros & Chocolate", ["donuts", "cinnamon", "melted_chocolate|hot_chocolate"]],
	["Banana Split", ["ice_cream", "banana/c1", "chocolate|melted_chocolate|caramel"]],
	["Ice Cream Sundae", ["ice_cream", "melted_chocolate|caramel|chocolate", "sprinkles|whipped_cream"]],
	["Affogato", ["ice_cream", "brewed_coffee"]],
	["Ice Cream Cone-ish", ["ice_cream", "biscuits|crackers"]],
	["{} Ice Cream", ["ice_cream"]],
	["{} Frozen Yogurt", ["frozen_yogurt"]],
	["{} Ice Pop", ["ice_pop"]],
	["{} Jelly", ["jelly"]],
	["Jelly & Ice Cream", ["jelly", "ice_cream"]],
	["Trifle", ["jelly|custard", "custard|whipped_cream", "cake|biscuits|raspberry|strawberry"]],
	["Chocolate Mousse", ["chocolate_mousse"]],
	["Strawberries & Cream", ["strawberry", "whipped_cream|cream"]],
	["Chocolate Strawberries", ["strawberry", "melted_chocolate"]],
	["Chocolate Fondue", ["melted_chocolate", "strawberry|banana|marshmallow|pineapple", "#fruit|marshmallow"]],
	["Apple Crumble", ["apple|green_apple:bake", "oats|flour:bake", "butter"]],
	["Crumble & Custard", ["apple|green_apple|plum|pear|raspberry:bake", "oats|flour:bake", "custard"]],
	["Baked Apple", ["apple|green_apple/w:bake", "cinnamon|honey|brown_sugar"]],
	["Grilled Peaches", ["peach|pineapple/c1:grill", "honey|ice_cream|yogurt"]],
	["Poached Pears", ["pear:boil", "sugar|honey|cinnamon"]],
	["S'mores", ["marshmallow:cooked", "chocolate|melted_chocolate", "biscuits|crackers"]],
	["Toasted Marshmallows", ["marshmallow:cooked"]],
	["Caramel Apple", ["apple|green_apple", "caramel"]],
	["Mango Sticky Rice", ["steamed_rice", "mango", "coconut_milk"]],
	["Rice Pudding", ["steamed_rice", "milk:boil", "sugar|cinnamon"]],
	["Custard Bowl", ["custard"]],
	["Eton Mess", ["whipped_cream", "strawberry|raspberry", "biscuits|cookies|sugar"]],
	["Fruit & Yogurt", ["yogurt", "#fruit"]],
	["Acai-ish Bowl", ["smoothie", "granola|banana|blueberry"]],
	["Rocky Road", ["melted_chocolate", "marshmallow", "biscuits|almonds|walnuts|raisins"]],
	["Chocolate Bark", ["melted_chocolate:chill,freeze", "almonds|cashews|raisins|sprinkles|walnuts"]],
	["Gummy Sundae", ["ice_cream", "gummy_bears"]],
	["Nutty Granola Bars", ["flapjacks", "almonds|walnuts|cashews|raisins|peanuts"]],
	# Drinks
	["{} Smoothie", ["smoothie"]],
	["{} Juice", ["juice"]],
	["{} Milkshake", ["milkshake"]],
	["Lemonade", ["lemonade"]],
	["Pink Lemonade", ["lemonade", "strawberry|raspberry"]],
	["Mint Lemonade", ["lemonade", "mint"]],
	["Hot Chocolate", ["hot_chocolate"]],
	["Hot Chocolate & Marshmallows", ["hot_chocolate", "marshmallow"]],
	["Mocha", ["hot_chocolate", "brewed_coffee"]],
	["Cup of Tea", ["brewed_tea"]],
	["English Tea", ["brewed_tea", "milk"]],
	["Honey Lemon Tea", ["brewed_tea", "honey", "lemon"]],
	["Iced Tea", ["iced_tea"]],
	["Peach Iced Tea", ["iced_tea", "peach|lemon"]],
	["Black Coffee", ["brewed_coffee"]],
	["Latte", ["brewed_coffee", "milk"]],
	["Iced Coffee", ["iced_coffee"]],
	["Frappé", ["frappe"]],
	["Vanilla Latte", ["brewed_coffee", "milk", "vanilla"]],
]

## Ingredient pairs that taste great together (bonus for off-menu creations).
const PAIRS := [
	["tomato", "basil"], ["tomato", "mozzarella"], ["apple", "cinnamon"], ["banana", "peanut_butter"],
	["strawberry", "cream"], ["strawberry", "chocolate"], ["bacon", "egg"], ["ham", "cheese"],
	["salmon", "lemon"], ["white_fish", "lemon"], ["chicken", "garlic"], ["chicken", "lemon"],
	["beef", "mushroom"], ["beef", "black_pepper"], ["lamb_chop", "mint"], ["pork_chop", "apple"],
	["duck", "orange"], ["avocado", "lime"], ["mango", "chili"], ["pineapple", "ham"], ["honey", "bacon"],
	["maple_syrup", "bacon"], ["garlic", "butter"], ["onion", "beef"], ["potato", "cheese"],
	["chili", "chocolate"], ["shrimp", "garlic"], ["ginger", "soy_sauce"], ["sesame_oil", "soy_sauce"],
	["feta", "watermelon"], ["goat_cheese", "beetroot"], ["blue_cheese", "pear"], ["brie", "grapes"],
	["peach", "cream"], ["coconut_milk", "curry_paste"], ["lime", "cilantro"], ["corn", "butter"],
	["carrot", "ginger"], ["spinach", "garlic"], ["mushroom", "garlic"], ["egg", "cheese"],
	["chicken_wings", "hot_sauce"], ["fries", "ketchup"], ["nori", "salmon"], ["rice", "soy_sauce"],
	["yogurt", "honey"], ["oats", "banana"], ["coffee", "milk"], ["chocolate", "marshmallow"],
	["raspberry", "white_chocolate"], ["cherry", "chocolate"], ["lemon", "sugar"], ["olive_oil", "basil"],
	["tuna", "mayonnaise"], ["sausage", "mustard"], ["frankfurter", "ketchup"], ["lamb_mince", "cumin"],
	["sweet_potato", "cinnamon"], ["pumpkin", "nutmeg"], ["prosciutto", "melon"], ["walnuts", "honey"],
]

## Sweet-only and savoury-only ingredients: mixing them without a reason costs stars.
const SWEET := ["sugar", "brown_sugar", "icing_sugar", "chocolate", "white_chocolate", "cocoa", "choc_spread",
	"sprinkles", "marshmallow", "gummy_bears", "jam", "ice_cream", "whipped_cream", "frosting", "cake",
	"cookies", "muffins", "donuts", "caramel", "melted_chocolate", "custard", "brownies", "cheesecake",
	"jelly", "golden_syrup", "condensed_milk", "vanilla", "cereal", "milkshake", "smoothie", "mug_cake",
	"chocolate_mousse", "ice_pop", "frozen_yogurt", "tiramisu", "cookie_dough", "cake_batter", "biscuits"]
const SAVORY_CATS := ["meat", "fish"]
const SAVORY := ["onion", "red_onion", "garlic", "shallot", "soy_sauce", "fish_sauce", "worcestershire",
	"ketchup", "mustard", "bbq_sauce", "mayonnaise", "mayo", "aioli", "gravy", "cheese_sauce", "curry_powder",
	"curry_paste", "garam_masala", "cumin", "paprika", "cajun", "garlic_powder", "black_pepper", "anchovies",
	"capers", "olives", "pickles", "miso", "gochujang", "hot_sauce", "sriracha", "ranch", "broth",
	"tomato_sauce", "tomato_paste", "pesto", "hummus", "tzatziki", "salsa", "guacamole", "broccoli",
	"cauliflower", "cabbage", "kale", "leek", "celery", "mushroom", "eggplant", "parmesan", "blue_cheese"]
## Sweet + savoury combos that are actually lovely.
const SWEET_OK := ["bacon", "ham", "prosciutto", "chicken", "chicken_wings", "pork_belly", "pork_chop", "duck",
	"ribs", "salmon", "chili", "peanut_butter", "cheese", "brie", "goat_cheese", "blue_cheese", "cream_cheese",
	"ricotta", "mascarpone", "salt", "pancakes", "waffle", "french_toast", "teriyaki", "hoisin", "sweet_chili"]

static var _rules: Array = []
static var _recipes: Array = []
static var _how: Dictionary = {}
static var _pairs: Dictionary = {}


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
	for pr in PAIRS:
		_pairs[pr[0] + "+" + pr[1]] = true
		_pairs[pr[1] + "+" + pr[0]] = true


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
		var alt := {"id": "", "cats": [], "any": false, "cut": 0, "whole": false, "style": "", "coat": false}
		var base: String = bits[0]
		if base == "*":
			alt["any"] = true
		elif base.begins_with("#"):
			var c := base.substr(1)
			alt["cats"] = ["meat", "fish", "protein"] if c == "protein" else [c]
		else:
			alt["id"] = base
			assert(ING.has(base), "Unknown ingredient in spec: " + s)
		for k in range(1, bits.size()):
			var f: String = bits[k]
			match f:
				"w": alt["whole"] = true
				"coat": alt["coat"] = true
				"slice", "dice", "free":
					alt["style"] = f
					alt["cut"] = maxi(int(alt["cut"]), 1)
				_: alt["cut"] = int(f.substr(1))
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
			if alt["style"] != "" and d.get("style", "") != alt["style"]:
				continue
			if alt["coat"] and d.get("coat", "") == "":
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
	if ms.has(d.get("cold", "")):
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
	return {"id": id, "cut": 0, "style": "", "coat": "", "washed": not flag(id, "d"), "cook": "",
		"cooked": false, "cold": "", "burnt": false, "pm": "", "prog": 0.0, "br": 0.0, "ch": 0.0}


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


## True when the board should offer slice / dice / mince / free cut.
static func has_styles(id: String) -> bool:
	return id != "mix" and cut_max(id) >= 2 and not CUT_WORDS.has(id)


static func cut_word(id: String, cut: int, style := "") -> String:
	if cut == 1 and STYLE_WORDS.has(style):
		return STYLE_WORDS[style]
	var words: Array = CUT_WORDS.get(id, DEFAULT_CUT_WORDS)
	if cut >= words.size():
		return DEFAULT_CUT_WORDS[mini(cut, 3)]
	return words[cut]


## Shop packaging (bottles, sacks, jars...) whose contents get poured or sprinkled out.
const PACKS := ["sack", "shaker", "mill", "jar", "bottle", "squeeze", "carton", "can", "tub"]


static func is_pack(id: String) -> bool:
	return id != "mix" and not flag(id, "i") and ING[id][2] in PACKS


## Things you shake, grind or squeeze ONTO food rather than serve as a lump.
static func is_topping(id: String) -> bool:
	if id == "mix":
		return false
	if flag(id, "s") or flag(id, "l"):
		return true
	return id in ["sprinkles", "sesame_seeds", "cocoa", "icing_sugar", "breadcrumbs", "panko", "coconut_flakes",
		"jam", "peanut_butter", "choc_spread", "tahini", "honey", "caramel", "melted_chocolate", "pesto",
		"mayo", "aioli", "salsa", "guacamole", "hummus", "tzatziki", "whipped_cream", "frosting", "gravy",
		"cheese_sauce", "custard", "tomato_sauce", "garlic_butter", "vinaigrette", "sour_cream", "cream_cheese"]


## Powder / seasoning (dusted on) vs sauce (drizzled).
static func is_dust(id: String) -> bool:
	return id != "mix" and (ING[id][1] == "spice" and not flag(id, "l") or id in ["sugar", "brown_sugar",
		"icing_sugar", "cocoa", "sprinkles", "sesame_seeds", "breadcrumbs", "panko", "coconut_flakes", "salt",
		"black_pepper", "flour", "cornflour", "gelatin"]) and id != "vanilla"


## Marks shop-packaged leaves as a poured/scooped portion (no bottle on the plate).
static func portion(d: Dictionary) -> void:
	for l in leaves(d):
		if is_pack(l["id"]):
			l["portion"] = true


static func coatable(l: Dictionary) -> bool:
	var id: String = l["id"]
	var cat: String = ING[id][1]
	return l.get("coat", "") == "" and not COATINGS.has(id) and id != "beaten_egg" and (cat in ["meat", "fish", "protein", "veg"]
		or id in ["mozzarella", "cheese", "halloumi", "brie", "cooked_macaroni", "steamed_rice", "banana", "apple",
		"pineapple", "egg", "boiled_egg", "frankfurter"])


## Mixing-bowl breading: coatables + a coating (+ optional egg wash) -> coated pieces.
## Returns {coated: [...], rest: [...]}; empty coated when nothing to bread.
static func coat(items: Array) -> Dictionary:
	var coats := []
	var wash := []
	var targets := []
	var rest := []
	for d in items:
		if d["id"] == "mix":
			rest.append(d)
			continue
		if COATINGS.has(d["id"]):
			coats.append(d)
		elif d["id"] == "beaten_egg" or (d["id"] == "egg" and int(d.get("cut", 0)) > 0) or d["id"] in ["milk", "buttermilk"]:
			wash.append(d)
		elif coatable(d):
			targets.append(d)
		else:
			rest.append(d)
	if coats.is_empty() or targets.is_empty():
		return {"coated": [], "rest": items}
	var kind: String = COATINGS[coats[0]["id"]]
	for c in coats:
		if COATINGS[c["id"]] in ["crumb", "panko"]:
			kind = COATINGS[c["id"]]
	for t in targets:
		t["coat"] = kind
		t["washed"] = true
	return {"coated": targets, "rest": rest}


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
			if method in COLD:
				out["cold"] = method
			elif BASE_TIME.has(method):
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
		if d["cook"] == "bake" and id in ["bread", "cake_batter", "batter", "dough", "cookie_dough", "pastry", "puff_pastry"]:
			adj = "Baked"
		if d["cook"] == "fry" and ING[id][1] == "meat" and d.get("coat", "") == "":
			adj = "Seared"
		if d.get("coat", "") != "" and d["cook"] in ["fry", "deepfry"]:
			adj = "Crispy"
		words.append(adj)
	elif flag(id, "r") and not d.get("cooked", false):
		words.append("Raw")
	if d.get("cold", "") == "freeze" and not flag(id, "n"):
		words.append("Frozen")
	elif d.get("cold", "") == "chill" and not flag(id, "n"):
		words.append("Chilled")
	if d.get("coat", "") != "":
		words.append(COAT_WORDS[d["coat"]])
	var cut: int = d.get("cut", 0)
	if cut > 0:
		words.append(cut_word(id, cut, d.get("style", "")))
	words.append(nm)
	return " ".join(words)


static func food_name(d: Dictionary) -> String:
	if d["id"] != "mix":
		return leaf_name(d)
	return identify(d["parts"])["name"]


static func _priority(d: Dictionary) -> int:
	var id: String = d["id"]
	var cat: String = ING[id][1]
	if flag(id, "s") or is_dust(id):
		return 0
	match cat:
		"meat", "fish", "protein": return 6
		"made": return 4 if flag(id, "l") else 5
		"veg", "fruit": return 3
		"grain": return 2
		"dairy": return 2
	return 1


const BASES := {
	"hot_dog_bun": "{} Hot Dog", "bun": "{} Burger", "brioche_bun": "{} Brioche Burger",
	"bagel": "{} Bagel", "croissant": "{} Croissant", "english_muffin": "{} Muffin Stack",
	"baguette": "{} Baguette", "bread": "{} Sandwich", "toast": "{} on Toast", "pita": "{} Pita",
	"naan": "{} Naan Wrap", "tortilla": "{} Wrap", "taco_shell": "{} Tacos", "rice_paper": "{} Rolls",
	"pizza": "{} Pizza", "cake": "{} Cake", "pancakes": "{} Pancakes", "waffle": "{} Waffles",
	"steamed_rice": "{} Rice Bowl", "cooked_quinoa": "{} Quinoa Bowl", "cooked_couscous": "{} Couscous",
	"cooked_pasta": "{} Pasta", "cooked_penne": "{} Penne", "cooked_macaroni": "{} Mac",
	"cooked_noodles": "{} Noodles", "cooked_rice_noodles": "{} Rice Noodles", "ice_cream": "{} Sundae",
	"frozen_yogurt": "{} Froyo", "porridge": "{} Porridge", "overnight_oats": "{} Overnight Oats",
	"nori": "{} Roll", "fries": "{} Loaded Fries", "sweet_potato_fries": "{} Loaded Fries",
	"tortilla_chips": "{} Nachos", "crackers": "{} Crackers", "mashed_potato": "{} & Mash", "pie": "{} Pie",
	"smoothie": "{} Smoothie", "milkshake": "{} Milkshake", "juice": "{} Juice", "yogurt": "{} Yogurt Bowl",
	"bread_loaf": "{} Loaf", "donuts": "{} Donuts", "brownies": "{} Brownies", "cheesecake": "{} Cheesecake",
	"hash_browns": "{} Hash", "puff_pastry": "{} Pastry", "pastry": "{} Tart", "lettuce": "{} Salad",
	"kale": "{} Kale Salad", "spinach": "{} Spinach Salad",
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
	if has.call(["chili", "curry_powder", "chili_flakes", "hot_sauce", "sriracha", "jalapeno", "cajun", "gochujang", "curry_paste"]):
		adj = "Spicy "
	elif has.call(["bbq_sauce"]):
		adj = "BBQ "
	elif has.call(["honey", "maple_syrup", "caramel", "sugar", "golden_syrup", "brown_sugar"]) and _count_cats(ls, ["meat", "fish"]) > 0:
		adj = "Sticky "
	elif has.call(["cheese", "mozzarella", "parmesan", "cheese_sauce", "feta", "brie"]) and not ab.contains("Cheese") \
			and not ab.contains("Mozzarella") and not ab.contains("Parmesan") and not ab.contains("Cheddar"):
		adj = "Cheesy "
	elif has.call(["garlic", "garlic_powder", "garlic_butter", "aioli"]) and not ab.contains("Garlic"):
		adj = "Garlicky "
	elif has.call(["herbs", "oregano", "rosemary", "parsley", "cilantro", "basil", "mint"]) and not ab.contains("Herb"):
		adj = "Herby "
	elif has.call(["lemon", "lime"]) and not ab.contains("Lemon") and not ab.contains("Lime"):
		adj = "Zesty "
	var coated := 0
	for l in ls:
		if l.get("coat", "") != "":
			coated += 1
	if coated > 0 and adj == "":
		adj = "Crispy " if _count_method(ls, "deepfry") + _count_method(ls, "fry") > 0 else "Breaded "
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
	var cold := ""
	var puree := 0
	for l in ls:
		if int(l.get("cut", 0)) >= 3:
			puree += 1
		if l.get("cooked", false) and l.get("cook", "") != "":
			counts[l["cook"]] = counts.get(l["cook"], 0) + 1
		if l.get("cold", "") != "":
			cold = l["cold"]
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
			if coated > 0:
				return adj + ab + " Bites"
			return adj + "Crispy " + ab
		"bake":
			if n >= 3:
				return adj + ab + " Bake"
			return adj + "Roasted " + ab
		"grill":
			if n >= 3:
				return adj + "Grilled " + ab + " Platter"
			return adj + "Grilled " + ab
		"microwave":
			return adj + "Zapped " + ab
		"toast":
			return adj + "Toasted " + ab
	if cold == "freeze":
		return adj + "Frozen " + ab + " Treat"
	if cold == "chill":
		return adj + "Chilled " + ab
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
		if flag(l["id"], "s") or is_dust(l["id"]) or seen.has(l["id"]):
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

static func _is_sweet(id: String) -> bool:
	return id in SWEET or ING[id][1] == "sweet" or (ING[id][1] == "fruit" and not id in ["avocado", "lemon", "lime", "tomato"])


static func _is_savory(id: String) -> bool:
	return id in SAVORY or ING[id][1] in SAVORY_CATS


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
	var sweet := 0
	var savory := 0
	var sweet_ok := false
	for l in ls:
		var id: String = l["id"]
		kinds[id] = true
		if flag(id, "s") or is_dust(id):
			seasoned = true
		if _is_sweet(id):
			sweet += 1
		if _is_savory(id):
			savory += 1
		if id in SWEET_OK:
			sweet_ok = true
		if l.get("burnt", false):
			q -= 1.2
			burnt = true
			continue
		if flag(id, "r") and not l.get("cooked", false):
			var sashimi: bool = id in ["salmon", "tuna"] and int(l.get("cut", 0)) >= 1
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
		q += 0.6
		notes.append("Wildly creative!")
		# off-menu dishes are judged on whether they make sense
		var good := 0
		var ids := kinds.keys()
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				if _pairs.has(ids[a] + "+" + ids[b]):
					good += 1
		if good > 0:
			q += minf(0.9, good * 0.45)
			notes.append("Flavours that belong together")
		if sweet > 0 and savory > 0 and not sweet_ok:
			q -= 1.0
			notes.append("Sweet and savoury fighting each other...")
		var protein := _count_cats(ls, ["meat", "fish", "protein"]) > 0
		var veg := _count_cats(ls, ["veg"]) > 0
		var carb := _count_cats(ls, ["grain"]) > 0 or kinds.has("steamed_rice") or kinds.has("fries") \
			or kinds.has("cooked_pasta") or kinds.has("mashed_potato") or kinds.has("toast")
		if protein and veg and carb:
			q += 0.4
			notes.append("A proper balanced meal")
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
	var style := ""
	var coated := false
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
		if alt["style"] != "":
			style = alt["style"]
		coated = coated or alt["coat"]
	var s := " or ".join(names)
	var steps := []
	if cut >= 3:
		steps.append("blend")
	elif style != "":
		steps.append({"slice": "slice", "dice": "dice", "free": "cut up"}[style])
	elif cut > 0:
		var first: String = sp["alts"][0]["id"]
		var word: String = cut_word(first, cut) if first != "" else DEFAULT_CUT_WORDS[cut]
		steps.append(CUT_VERB.get(word, "chop"))
	if whole:
		steps.append("keep whole")
	if coated:
		steps.append("bread it (bowl + breadcrumbs/batter)")
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
