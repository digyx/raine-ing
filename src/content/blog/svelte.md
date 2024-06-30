---
title: I Want to Love Svelte
description: JavaScript haunts me in my sleep.
pubDatetime: 2024-06-30T06:00:00Z
modDatetime: 2024-06-30T06:00:00Z
tags:
  - svelte
  - programming
---

Svelte was supposed to be the answer to the horrors that are React or Angular, and it's promised to be heads-and-shoulders above Vue, but it's held back by the same thing as the other three: JavaScript.

**NOTE**: _I use Typescript. This only solves some of the problems while introducing others._

## Table of Contents

## The Promise

I genuinely enjoy writing Svelte code. Templates are better than JSx, the syntax feels _right_, and Sveltekit makes intuitive sense to me. Everything works exactly how I'd expect it works. If you're writing a fancy-looking CRUD app, then Sveltekit is genuinely difficult to beat. Skeleton makes it easy for you app to look good, types are passed acorss the client-server divide, so intellisense works as you'd want it to. Oh, did I mention that SSR is built-in and enabled by default?

Sveltekit promises a fantastic development experience while also being the fastest web framework. While it delivers on some of these promises, we're not here to talk about how good it is. That's for later. We're here today to talk about the problem Sveltekit cannot solve.

## Welcome to My Nightmare

If you like JavaScript, I'm happy for you. I really am. You can make websites and easily share your work with so many people using a language you _love_ working with.

I don't.

### Exceptions

While some libraries have started using errors as values, most don't, and some that do even throw exceptions still (_glares at [Supabase](https://github.com/supabase/supabase-js/blob/b8a5d7137de9985d09fb5820b444b1f7a8a580f3/src/SupabaseClient.ts#L74)_). Unlike Java, you don't have to declare what exceptions a function could throw. Error handling doesn't actually happen at development time, unlike in a language like Rust, it happens after your application crashes. You're not actually sure where an exception is going to be thrown until it's actually thrown. Documentation could help you point out where some of those palces could be, but you will almost definitely miss at least one. I won't go into the specifics of exceptions vs errors as values. See [this article](https://humanlytyped.hashnode.dev/away-from-exceptions-errors-as-values) for why errors as values are better.

Even in languges like Rust and Golang, you're not sure if a returned error is actually going to be an issue, but you can guarantee that there _might_ be an error there.

### Concurrency

Let's say we have a long running task that we want to spin up in the background. If we're using Golang, we spin up that task in a goroutine, return the JobID, and then track the progress of that Job either using a channel or a synchronus map. This breaks down once you're running your application on more than one server[^1], but Node doesn't even allow you to get to that point.

If you want to spinup background tasks in JavaScript, you have to either start and _entirely different Node process_ using [worker threads](https://nodejs.org/api/worker_threads.html#worker-threads) or use a task broker library like BullMQ. Okay, our overhead went from a synchronous map in Golang to needing redis and background workers, not to mention the ovehead of learning a new library.

### Bundling and the Runtime<sup>TM</sup>

In Golang, Rust, Java, etc. tha language toolchain can compile your entire application down to a single artifact. This artifact can be ran as either an executable, if it's natively compiled, or using a bytecode VM, like the JVM. JavaScript also compiles down to a single artifct<sup>\*</sup> that is ran in a VM<sup>\*\*</sup>, but not by the language toolchain.

Of the available bundlers, the two most populer are Webpack and Vite. No one[^2] likes Webpack, so everyone now uses Vite. How does Vite work? Uhhhh `npm create svelte@latest` just sets Vite up for you. Most JavaScript devs don't actually understand how to use Vite[^3], let alone how it works, but the 5% who do understand Vite write great plugins for us to use. Anyway, once `vite build` runs, we have a single JS file we can run using node! Right...?

Lmao, no, of course not. To make up for our horrifically bloated frontends, Vite automatically chunks our JS into multiple files so they can either be loaded in in parallel or requested only when they're needed. Now we have an entire `dist` directory to ship, not just a single artifact. But we just run that with Node, right...?

Hahaha, you _could_, but why would you use Node when you could use _\*checks notes\*_ I'm sorry, WHAT?! We have Deno, Bun, workerd, LLRT, Winter, and more... Why pick one over another? Well, Node is the standard, Deno is apparently more secure and nicer to work with, Bun is _fast_ but also missing some features, workerd and LLRT start up fast, and Winter is...anyway, there's a LOT of runtimes, and you'll either use Node or Bun or fall down a deep rabbit hole.

I won't go into the dicussion of where you should run your JavaScript app. That's even worse.

## What Do I Do Now?

Suffer? Yeah, mostly just suffer.

In all seriousness, the majority of apps don't need a frontend framework. Using HTMX, Golang, and Templ, you can make a damn good website. Prefer Rust? Use Maud instead of Templ. If you absolutely need React/Angular/Vue/Svelte/Solid/whatever then sure, you do you, but I don't have to do this. Sveltekit has a really, really, _really_ great developer experience, but using Svlete means I need to use JavaScript, and I just can't do that without going insane.

This article is mostly me venting about JavaScript, but I plan on doing a much more in depth review of Sveltekit once I've hit the 100 hour mark in the language. I have ~20 hours left, so look forward to that later.

Peace out, girl scout.

~ Raine

---

[^1]: You know which language doesn't have this issue? Elixr and other OTP languages.
[^2]: I'm generalizing, but do you really _like_ Webpack? Really?? Why???
[^3]: Yes, I know the answer is "read the docs" but that's yet another thing I need to learn that other languages have built-in.
