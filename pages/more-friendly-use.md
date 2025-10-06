# Making Gleam's Beloved "Use" Statement More Friendly

I believe `use` combined with a `case` statement (*referred to as `use-case` from now on*) would be a better fit for Gleam than the current implementation of `use` combined with a function call (*referred to as `use-fn` from now on*). In this document, I will explore why.

I adore Gleam. It is the language I want to write the most. I write this not as a shallow critique of Gleam, but in the hope of starting productive conversations around something I value. I also think that the `use` keyword design is geniusly clever and elegant, so props to Louis and the Gleam community for the fantastic work there.

# The "Use" Status Quo

While `use-fn` has potential for a wide range of use cases, it is overwhelmingly used for error handling within Gleam. That raises the question: if the primary use for `use-fn` is error handling, then why is the feature not more tuned towards it? After all, features that are focused and simple are more friendly than features that are broad and powerful, right?

I believe this is where `use-case` could come in, as it is a less powerful version of `use-fn` that is better suited for error handling, while also providing valuable new ways to express bespoke `case` statements that are not feasible today.

# The "Use-Case" Rational

The core concept is a statement that behaves similarly to a `case` statement, but leverages the `use` keyword to allow writing the first arm without indentation.

Two goals motivate the addition of a `use-case` statement:
1. To make the prevalent guard statement/`use`-based error handling patterns in Gleam more friendly, lowering the practical barrier to entry of the language as a whole.
2. To avoid nested happy-path indentation in bespoke case statements, making Gleam code more readable and enjoyable to work with.

The `use-case` statement can cover all guard/early return use cases of `use-fn`, but with more flexibility and without the need to be used with functions, allowing for more immediately explicit code, less function definition boilerplate, and more overall friendliness.

## "Use-Case" Example

Take the following code snippet, where we want to conditionally run logic based on the `Result` returned by `my_result_func`:

```gleam
case my_result_func(input_val) {
  Ok(val) -> {
    echo val
    // continue lots of happy-path logic
  }
  Error(_) -> Error(Nil)
}
```

We can employ a `use-fn` statement to avoid this indentation of our happy-path logic, and rewrite it as:

```gleam
import gleam/result

use val <- result.try(
  my_result_func(input_val)
  |> result.replace_error(Nil),
)
echo val
// continue lots of logic
```

This is clever! But has a couple of areas that could be improved:
1. The user has to import an external module
2. The user has to understand what the `result.try` function does, and the implementation details of how the `Result` type is handled are hidden across the bodies of multiple functions
3. It is not very flexible, and any change in logic requires using (writing or learning) another function

In comes the `use-case` statement, which addresses those things! We could write the same logic as:

```gleam
use Ok(val) <- case my_result_func(input_val) {
  Error(_) -> Error(Nil)
}
echo val
// continue lots of logic
```

It has the same arms as the regular `case` statement above, but the `use` keyword allows us to move the block of the first arm to the current indentation level. `use-case` provides us with all the typical benefits of a `use-fn` statement for error handling, but in a more explicit and flexible manner. Not only are there fewer tokens than in the `use-fn` example, but it is also easier to follow.

This `use-case` syntax can be used in place of all calls to `result.try` within a `use-fn` statement. For a larger function call, this may look something like:

`use-fn` example:
```gleam
import gleam/result

use res <- result.try(
  start_system(
    email_client,
    logger,
    context,
  )
  |> result.replace_error("Unable to start"),
)
echo res
```

 `use-case` example:
 ```gleam
use Ok(res) <- case start_system(
  email_client,
  logger,
  context,
) {
  Error(Nil) -> Error("Unable to start")
}
echo res
```

# Weighing "Use-Case" vs "Use-Fn" for Error Handling

Compared to `use-fn`, `use-case` for error handling is more friendly to both new and experienced Gleam developers because it:

1. Is easier to learn and read (implementation details are not hidden within function bodies)
2. Type errors can highlight only the invalid arm instead of the entire `use` statement (making them significantly more understandable)
3. Encourages better error handling by always presenting the error cases to the user instead of hiding them away in a function body
4. Does not require mixing with pipe operators and anonymous functions to achieve error transformation (which may be unfamiliar to new Gleam users)
5. Is more flexible
6. Is lazy by default
7. Leans more into Gleam's pattern matching (helping new users explore its functionality)
8. Requires less function definition boilerplate for every variation of logic (eg, `result.try` vs. `result.try_recover`, or `bool.guard` vs. `bool.lazy_guard`)
9. Generally uses fewer lines and fewer tokens (except for the simplest `use .. <- result.try(..)` case)
10. Has fewer things wrapped in parentheses (reducing visual clutter)
11. Does not depend on importing external functions
12. Has a similar feel to Zig's error handling and is easier to rationalize about if already familiar with pattern matching in general

Let's explore a couple of these points.

## Ease of Learning

`use-fn` is by far the most challenging concept to learn in Gleam. `use-case` retains the core benefits of `use-fn` for error handling, but is significantly easier to learn and use. Considering a world where both `use-case` and `use-fn` exist, `use-case` would be a valuable step to learn before learning `use-fn`. The learning path would be `case` -> patterns -> `use-case` -> `use-fn`, which is a much more gradual and natural path to follow. Currently, there is nothing to ease new users into `use-fn`.

If `use-case` were widely used where `use-fn` is used today for error handling, it would lower Gleam's barrier to entry as a whole.

## Ease of Debugging

A large part of Gleam's famed friendliness is its very human-readable compiler errors. Unfortunately, type errors caused by `use-fn` can be very difficult to understand. Because `use-case` clearly retains the distinct arms of a case statement, the compiler errors can be much more precise in highlighting the part of the statement that the error comes from, making it easier to understand and fix.

## Cost of Good Error Handling

The biggest critique against Rust's `?` operator is that it makes ignoring errors too easy. Because ignoring errors is easy, the perceived cost of handling those errors is high, leading users to not properly handle errors at all. Though `use-fn` is a significant step in the right direction, I still believe it ultimately falls short in the same way `?` does: it is too easy to write `use .. <- result.try(..)`, completely ignoring the error condition.

Compare ignoring versus handling an error with `use-fn`:

```gleam
// Ignoring the error case
use char <- result.try(string.first(my_input))
```

```gleam
// Handling the error case
use char <- result.try(
  string.first(my_input)
  |> snag.replace_error("Unable to get first character in: " <> my_input),
)
```

Adding a clause to handle the error added three lines to a previously one-line statement! The drastic difference in line count is a high cost that users will not want to pay unless they really believe the error has a high likelihood of occurring. The result is numerous unhandled errors, leading to a more frustrating debugging experience, which in turn contributes to fatigue with the language as a whole.

Now, let's compare ignoring versus handling an error with `use-case`

```gleam
// Ignoring the error case
use Ok(char) case string.first(my_input) {
  Error(Nil) -> Error(Nil)
}
```

```gleam
// Handling the error case
use Ok(char) <- case string.first(my_input) {
  Error(Nil) -> snag.error("Unable to get first character in: " <> my_input)
}
```

Adding a clause to handle the error added no lines to the size of the original statement; the user is forced to acknowledge the error case either way. Handling the error here is low cost, and this leads users to handle their errors properly more often.

The examples only get more extreme in favor of `use-case` as you try to handle an error with more complex logic. A low cost to handling errors is necessary for users to actually handle errors, which is of grave importance to giving users a feeling of ease when maintaining application code. Largely, I think the cost of handling errors vs ignoring them is directly proportional to the amount of fatigue users will feel for the language over time.

# Further "Use-Case" Examples

Please read through all the examples; they build and become more compelling as you progress through them!

## Result Handling - Mapping the Error
`use-fn` example:
```gleam
import gleam/result

use val <- result.try(
  my_result_func(input_val)
  |> result.map_error(fn(err) {
    io.println("Found error: " <> err)
    Error(err <> "!")
  }),
)
```

`use-case` example:
```gleam
use Ok(val) <- case my_result_func(input_val) {
  Error(err) -> {
    io.println("Found error: " <> err)
    Error(err <> "!")
  }
}
```

## Result Handling - Recovering from an Error
`use-fn` example:
```gleam
// new users need to learn the `try_recover` stdlib function
import gleam/result

use error <- result.try_recover(my_result_func(input_val))
```

`use-case` example:
```gleam
// if you know `use-case`, you know this!
use Error(err) <- case my_result_func(input_val) {
  Ok(ok) -> Ok(ok)
}
```

## Result Handling - Returning an Unwrapped Value
`use-fn` example:
```gleam
// needs an external library
import given

use page_path <- given.ok(
  get_page_route_from_model(model),
  else_return: fn(_nil) { #(model, effect.none()) },
)
```

`use-case` example:
```gleam
// no external library needed, can be done natively!
use Ok(page_path) <- case get_page_route_from_model(model) {
  _ -> #(model, effect.none())
}
```

## Boolean Guard
`use-fn` example:
```gleam
// user must choose between guard and lazy_guard, or unfavorably negate the `when` clause
import gleam/bool

use <- bool.lazy_guard(
  when: my_val < 45,
  return: fn() {
    io.println("Val is too low")
    Error("Low")
  },
)

let is_low = my_val < 45

use <- bool.guard(
  when: is_low,
  return: Error("My value is too low")
)

use <- bool.guard(
  when: !is_low,
  return: Error("My value is too high")
)
```

`use-case` example:
```gleam
// very explicit to the user which condition triggers which block
use True <- case my_val < 45 {
  False -> {
    io.println("Val is too high")
    Error(Nil)
  }
}

let is_low = my_val < 45

use True <- case is_low {
  False ->  Error("My value is too low")
}

use False <- case is_low {
  True -> Error("My value is too high")
}
```

## Multi-arm Error Recovery
`case` example (no way to do this with `use`):
```gleam
case response.status {
  200 -> {
    case parse_body(response.body) {
      Ok(body) -> {
        echo body
        // ...
      }
      Error(Nil) -> Error("Invalid body")
    }
  }
  404 -> Error("Not found")
  _ -> Error("Other error")
}
```

`use-case` example:
```gleam
use 200 <- case response.status {
  404 -> Error("Not found")
  _ -> Error("Other error")
}
use Ok(body) <- case parse_body(response.body) {
  Error(Nil) -> Error("Invalid body")
}
echo body
// ...
```

## Dual Result Handling
`use-fn` example:
```gleam
import gleam/result

use val1 <- result.try(my_result1)
use val2 <- result.try(my_result2)
```

`use-case` example:
```gleam
use Ok(val1), Ok(val2) <- case my_result1, my_result2 {
  _, _ -> Error(Nil)
}
```

## Multiple Nested Patterns
`case` example:
```gleam
case report_type, int.parse(report_id) {
  "weekly", Ok(report_id) ->
    case reports.get_report(context.report_actor, report_id) {
      Ok(weekly_report) ->
        wisp.ok()
        |> wisp.set_header("content-type", "text/plain")
        |> wisp.file_download(
          named: filepath.base_name(weekly_report.report_path)
          |> filepath.strip_extension
            <> ".csv",
          from: weekly_report.report_path,
        )

      Error(e) -> {
        wisp.html_response(
          snag.pretty_print(e) |> string_tree.from_string,
          500,
        )
      }
    }

  _, _ -> wisp.not_found()
}
```

`use-case` example:
```gleam
use "weekly", Ok(report_id) <- case report_type, int.parse(report_id) {
  _, _ -> wisp.not_found()
}

use Ok(weekly_report) <- case reports.get_report(context.report_actor, report_id) {
  Error(e) ->
    wisp.html_response(
      snag.pretty_print(e) |> string_tree.from_string,
      500,
    )
}

wisp.ok()
  |> wisp.set_header("content-type", "text/plain")
  |> wisp.file_download(
    named: filepath.base_name(weekly_report.report_path)
    |> filepath.strip_extension
      <> ".csv",
    from: weekly_report.report_path,
  )
```

## Different Types of Nested Patterns
`case` example (featuring Lustre!):
```gleam
case dict.get(model.active_discussions, discussion_id.view_id) {
  Ok(model) ->
    case model.stickied_discussion {
      option.Some(sticky_discussion_id) ->
        case discussion_id == sticky_discussion_id {
          True ->
            effect.from(fn(dispatch) {
              let timer_id =
                global.set_timeout(200, fn() {
                  dispatch(
                    DiscussionControllerSentMsg(
                      discussion.ClientUnsetStickyDiscussion(
                        discussion_id:,
                      ),
                    ),
                  )
                })

              dispatch(
                DiscussionControllerSentMsg(
                  discussion.UserStartedStickyCloseTimer(timer_id:),
                ),
              )
            })
          False -> effect.none()
        }
      option.None -> effect.none()
    }
  Error(Nil) -> effect.none()
}
```
`use-case` example:
```gleam
use Ok(model) <- case dict.get(model.active_discussions, discussion_id.view_id) {
  Error(Nil) -> effect.none()
}

use option.Some(sticky_discussion_id) <- case model.stickied_discussion {
  option.None -> effect.none()
}

use True <- case discussion_id == sticky_discussion_id {
  False -> effect.none()
}

effect.from(fn(dispatch) {
  let timer_id =
    global.set_timeout(200, fn() {
       dispatch(
        DiscussionControllerSentMsg(
          discussion.ClientUnsetStickyDiscussion(discussion_id:),
        ),
      )
    })

  dispatch(
    DiscussionControllerSentMsg(
      discussion.UserStartedStickyCloseTimer(timer_id:),
    ),
  )
})
```

# What Now?

After going through the `use-case` thought experiment, `use-fn` feels like how macros used to when I first started using Gleamus: too powerful for their own good.

I cannot speak with authority here as I am not a core team member, but it seems that Gleam has always chosen to favor features that are focused enough to solve a few concrete problems well over features that are broad and powerful enough to solve many problems in a general way. Broad and powerful features tend to be complex, while focused and simple features tend to be more friendly. The complexity of powerful features appears to be why macros are not present in Gleam; instead, there are a handful of dedicated keywords and LSP actions to help where macros would traditionally be useful.

So, what now? `use-fn` is already present in Gleam today, and `use-case` is not. The biggest downside to adding `use-case` at this point is that it would overlap with some of the current uses of `use-fn`. Though `use-fn` and `use-case` have many uses that do not overlap, they would be fighting each other for their most significant use case: error handling.

I think the only way we could add `use-case` now without creating chaos would be to introduce it along with two other changes: 1. A compiler warning when `use-fn` is used with the `result` module functions, and 2. An addition to the `gleam fix` command or an LSP command that would automatically convert any usage of `use-fn` with the `result` module functions to `use-case`.

It is up to the community to decide whether the `use-case` value proposition is worth adding to Gleam at this point. I think the short-term effort could be worth the long-term benefits, but I surely didn't consider all the nuances of this proposal. I would love to hear feedback from the community.
