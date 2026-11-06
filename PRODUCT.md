# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Young people worldwide who keep their social life, games and group chats on their phone. They open the app many times a day, in short sessions, one-handed, to see what friends are doing, reply and play.

## Product Purpose

Challengea puts a friend group's whole social life in one app: a home feed, stories, chats, short videos, a friends map, voice and video calls, and 1 vs 1 games. Success means friends post, reply and challenge each other daily instead of switching between several apps.

## Positioning

Chats are bubbles you physically drag together: dropping one friend on another creates a group. Friends can also challenge each other from anywhere in the app, and the server-checked result lands in their chat with a rematch.

## Operating Context

Used on phones, including mid-range Android devices, indoors and in daylight. The client is Flutter; the same code also builds for iOS and web. Without a server the app runs a demo with sample people.

## Capabilities and Constraints

- Keep every existing feature in any redesign: home feed, stories, post and story creation, reactions, comments, bubble chats, photos, voice notes, stickers, calls, games, videos, live and product cards, friends map, Ghost mode, profiles, sign-in, demo mode.
- Videos, live and live shop are placeholders for now.
- Comments, chat and reading must stay fast and legible; animation may never block a task.
- The Figma file "Challengea - N'TERI" also holds NTERI, a separate project that must not be touched.

## Brand Commitments

- The name is Challengea.
- The dragable chat bubbles are the product's defining idea.
- The old visual style, including the Figma look, is no longer binding (owner decision, 2026-11-06).
- The owner wants a modern, beautiful app with animation almost everywhere, and it must not feel childish.

## Evidence on Hand

Sample people, chats and posts in `app/lib/mock/` and `backend/.../mock/MockDataLoader.java` are demonstration data. There are no real users, testimonials or metrics.

## Product Principles

- The bubble is the idea: what makes Challengea different should be visible, not buried in one screen.
- Friends first: people and what they share come before interface.
- Playful, never childish: games and motion carry energy, with an adult sense of restraint.
- Fast under the thumb: every animation stays out of the way of reading, replying and scrolling.
