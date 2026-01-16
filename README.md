Project Name: KinoTaste 

Tagline: A Retro, Privacy-First Personal Cinema Curator powered by Gemini.

The Problem: Modern streaming algorithms trap users in filter bubbles, prioritizing engagement over quality. Finding a movie that matches a specific "vibe" or vague memory is nearly impossible with traditional keyword search.

The Solution: KinoTaste is a native iOS/iPadOS/watchOS app designed to bring back the joy of movie discovery. It features a retro "film roll" aesthetic and uses Google Gemini 2.0 to power its core feature: "Memory Fragments".

How I used Gemini: I integrated the Gemini API to transform the search experience.

Natural Language Understanding: Users can describe a scene, a feeling, or a complex plot (e.g., "90s movies with a plot twist set in space").

Structured Output: I used Gemini's prompt engineering to output strict JSON data, linking the AI's creative understanding with TMDB's metadata.

Personalized Context: Gemini generates a unique "Recommendation Reason" for each result, displayed as a highlighted note on the movie card, acting as a personal digital curator.

Tech Stack:

Language: Swift 6, SwiftUI

AI Model: Gemini 2.0

Data Persistence: SwiftData (Local-first privacy)

API: TMDB (Metadata), Google Generative AI SDK
