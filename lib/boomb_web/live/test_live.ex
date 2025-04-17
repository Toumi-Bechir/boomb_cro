defmodule BoombWeb.TestLive do
  use BoombWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    

    {:ok, socket }
  end

  
  def render(assigns) do
    ~H"""
            <!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Top Menu Bar</title>
    <!-- Include Tailwind CSS via CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100">
    <div class="bg-gray-900 text-white text-sm py-1 px-4 flex justify-between items-center">
        <div class="flex space-x-4">
            <a href="#" class="hover:underline">Sports</a>
            <a href="#" class="hover:underline">Fantasy</a>
            <a href="#" class="hover:underline">Casino</a>
            <a href="#" class="hover:underline">Extra</a>
        </div>
        <div class="flex space-x-4">
            <a href="#" class="hover:underline">Safe Gambling</a>
            <a href="#" class="hover:underline">Help</a>
        </div>
    </div>

    <!-- Main Menu Bar -->
    <header class="bg-gradient-to-r from-green-900 to-green-700 text-white py-4 px-6 flex justify-between items-center sticky top-0 z-10">
        <div class="text-2xl font-bold">
            <a href="#">bet365</a>
        </div>
        <nav class="hidden md:flex space-x-6">
            <a href="#" class="hover:underline">All Sports</a>
            <a href="#" class="hover:underline">Play</a>
            <a href="#" class="hover:underline">Casino</a>
        </nav>
        <div class="flex items-center space-x-3">
            <button class="text-white hover:text-gray-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                </svg>
            </button>
            <button class="bg-yellow-400 text-black font-semibold py-2 px-4 rounded-full hover:bg-yellow-500 transition">Join</button>
            <button class="bg-teal-500 text-white font-semibold py-2 px-4 rounded-full hover:bg-teal-600 transition">Log In</button>
        </div>
    </header>

    <!-- Main Content -->
    <main class="flex flex-col lg:flex-row min-h-screen">
        <!-- Left Sidebar (Favorites) -->
        <aside class="lg:w-1/3 w-full bg-gray-900 p-4 overflow-y-auto">
            <div class="flex items-center space-x-2 mb-4">
                <svg class="w-6 h-6 text-yellow-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"></path>
                </svg>
                <h2 class="text-lg font-semibold">FAVOURITES</h2>
            </div>
            <div class="flex space-x-4 mb-4 overflow-x-auto">
                <button class="bg-gray-700 text-white px-3 py-1 rounded-full">Soccer</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Tennis</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Basketball</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Beach Volley</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Cricket</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Curling</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Darts</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Esports</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Golf</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Greyhounds</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Handball</button>
                <button class="bg-gray-600 text-white px-3 py-1 rounded-full">Hockey</button>
            </div>
            <h3 class="text-xl font-semibold mb-2">Soccer</h3>
            <!-- Match Listings -->
            <div class="space-y-4">
                <!-- UEFA Europa League -->
                <div>
                    <h4 class="text-sm font-semibold text-gray-400">UEFA EUROPA LEAGUE</h4>
                    <div class="bg-gray-800 p-2 rounded">
                        <div class="flex justify-between items-center mb-2">
                            <div class="flex items-center space-x-2">
                                <span class="text-red-500">45:00</span>
                                <span>Lyon</span>
                            </div>
                            <span class="font-bold">1</span>
                        </div>
                        <div class="flex justify-between items-center mb-2">
                            <div class="flex items-center space-x-2">
                                <span class="text-red-500">45:00</span>
                                <span>Man Utd</span>
                            </div>
                            <span class="font-bold">1</span>
                        </div>
                        <div class="grid grid-cols-4 gap-2 text-center text-sm">
                            <span class="font-semibold">1</span>
                            <span class="font-semibold">X</span>
                            <span class="font-semibold">2</span>
                            <span></span>
                            <span class="bg-gray-700 py-1 rounded">5/2</span>
                            <span class="bg-gray-700 py-1 rounded">7/5</span>
                            <span class="bg-gray-700 py-1 rounded">7/4</span>
                            <span class="bg-green-600 py-1 rounded">+23</span>
                        </div>
                    </div>
                </div>
                <!-- Other Leagues (Simplified for Brevity) -->
                <div>
                    <h4 class="text-sm font-semibold text-gray-400">ENGLAND LEAGUE 2</h4>
                    <div class="bg-gray-800 p-2 rounded">
                        <div class="flex justify-between items-center mb-2">
                            <div class="flex items-center space-x-2">
                                <span class="text-red-500">45:00</span>
                                <span>Crewe</span>
                            </div>
                            <span class="font-bold">1</span>
                        </div>
                        <div class="flex justify-between items-center mb-2">
                            <div class="flex items-center space-x-2">
                                <span class="text-red-500">45:00</span>
                                <span>Cheltenham</span>
                            </div>
                            <span class="font-bold">1</span>
                        </div>
                        <div class="grid grid-cols-4 gap-2 text-center text-sm">
                            <span class="font-semibold">1</span>
                            <span class="font-semibold">X</span>
                            <span class="font-semibold">2</span>
                            <span></span>
                            <span class="bg-gray-700 py-1 rounded">17/10</span>
                            <span class="bg-gray-700 py-1 rounded">6/4</span>
                            <span class="bg-gray-700 py-1 rounded">4/1</span>
                            <span class="bg-green-600 py-1 rounded">+21</span>
                        </div>
                    </div>
                </div>
                <!-- Add more leagues as needed -->
            </div>
        </aside>

        <!-- Center Section (Betting Options) -->
        <section class="lg:w-2/5 w-full bg-gray-800 p-4">
            <h3 class="text-xl font-semibold mb-2">Soccer</h3>
            <div class="bg-gray-900 p-4 rounded">
                <div class="grid grid-cols-5 gap-2 text-center text-sm font-semibold">
                    <span></span>
                    <span>1</span>
                    <span>X</span>
                    <span>2</span>
                    <span></span>
                </div>
                <div class="grid grid-cols-5 gap-2 text-center text-sm">
                    <span class="font-semibold">FULL TIME RESULT</span>
                    <span class="bg-gray-700 py-1 rounded">5/2</span>
                    <span class="bg-gray-700 py-1 rounded">7/5</span>
                    <span class="bg-gray-700 py-1 rounded">7/4</span>
                    <span class="bg-green-600 py-1 rounded">+23</span>
                </div>
                <div class="grid grid-cols-5 gap-2 text-center text-sm mt-2">
                    <span class="font-semibold">MATCH GOALS</span>
                    <span class="bg-gray-700 py-1 rounded">11/1</span>
                    <span class="bg-gray-700 py-1 rounded">11/4</span>
                    <span class="bg-gray-700 py-1 rounded">2/5</span>
                    <span class="bg-green-600 py-1 rounded">+23</span>
                </div>
                <div class="grid grid-cols-5 gap-2 text-center text-sm mt-2">
                    <span class="font-semibold">ASIAN HANDICAP IN-PLAY</span>
                    <span class="bg-gray-700 py-1 rounded">7/4</span>
                    <span class="bg-gray-700 py-1 rounded">2/1</span>
                    <span class="bg-gray-700 py-1 rounded">9/2</span>
                    <span class="bg-green-600 py-1 rounded">+23</span>
                </div>
                <div class="grid grid-cols-5 gap-2 text-center text-sm mt-2">
                    <span class="font-semibold">GOAL LINE IN-PLAY</span>
                    <span class="bg-gray-700 py-1 rounded">2/5</span>
                    <span class="bg-gray-700 py-1 rounded">3/10</span>
                    <span class="bg-gray-700 py-1 rounded">3/10</span>
                    <span class="bg-green-600 py-1 rounded">+23</span>
                </div>
            </div>
        </section>

        <!-- Right Sidebar (Live Match Stats) -->
        <aside class="lg:w-1/4 w-full bg-gray-900 p-4">
            <div class="flex justify-between items-center mb-4">
                <span>Lyon 1</span>
                <span>Man Utd 1</span>
            </div>
            <div class="text-center text-red-500 mb-4">45:00</div>
            <!-- Field Graphic (Placeholder) -->
            <div class="bg-green-600 h-32 mb-4 rounded flex items-center justify-center">
                <span class="text-white">Field Graphic Placeholder</span>
            </div>
            <!-- Match Stats -->
            <div class="space-y-4">
                <div class="flex justify-between">
                    <span>2</span>
                    <div class="flex-1 mx-2">
                        <div class="bg-blue-500 h-2 rounded" style="width: 40%;"></div>
                    </div>
                    <span>3</span>
                </div>
                <div class="flex justify-between">
                    <span>4</span>
                    <div class="flex-1 mx-2">
                        <div class="bg-blue-500 h-2 rounded" style="width: 50%;"></div>
                    </div>
                    <span>4</span>
                </div>
                <div class="flex justify-between">
                    <span>Over 26.5 5/6</span>
                    <span>Under 26.5 5/6</span>
                </div>
            </div>
            <!-- Additional Stats -->
            <div class="mt-4 space-y-2">
                <div class="flex justify-between">
                    <span>0.21</span>
                    <span>x</span>
                    <span>0.66</span>
                </div>
                <div class="flex justify-between">
                    <span>40</span>
                    <span>Attacks</span>
                    <span>40</span>
                </div>
                <div class="flex justify-between">
                    <span>11%</span>
                    <span>Possession %</span>
                    <span>17%</span>
                </div>
                <div class="flex justify-between">
                    <span>60%</span>
                    <span></span>
                    <span>40%</span>
                </div>
                <div class="flex justify-between">
                    <span>7</span>
                    <span>Shots / On Target</span>
                    <span>3</span>
                </div>
            </div>
            <!-- Action Areas -->
            <div class="mt-4">
                <h4 class="text-sm font-semibold">ACTION AREAS</h4>
                <div class="flex justify-between text-sm">
                    <span>34.3%</span>
                    <span>44.2%</span>
                    <span>21.5%</span>
                </div>
            </div>
            <!-- Player Stats -->
            <div class="mt-4 space-y-2">
                <div class="flex justify-between">
                    <span>3</span>
                    <span>Key Passes</span>
                    <span>4</span>
                </div>
                <div class="flex justify-between">
                    <span>2</span>
                    <span>Goalkeeper Saves</span>
                    <span>1</span>
                </div>
                <div class="flex justify-between">
                    <span>85%</span>
                    <span>Passing Accuracy</span>
                    <span>89%</span>
                </div>
            </div>
        </aside>
    </main>
    
</body>
</html>
    """
  end
end