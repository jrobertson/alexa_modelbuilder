# Generate an Alexa Interaction Model using the alex_modelbuilder gem

    require 'alexa_modelbuilder'

    s =<<LINES
    invocation: quiz game

    PlayGame

      start the game
      start the quiz
      play the quiz
      start a quiz  

    types: 
      US_STATE_ABBR: AK, AL, AZ

    AMAZON.StopIntent
    LINES


    puts JSON.pretty_generate(AlexaModelBuilder.new(s).to_h)

Output:

<pre>
{
  "interactionModel": {
    "languageModel": {
      "invocationName": "quiz game",
      "intents": [
        {
          "name": "PlayGame",
          "samples": [
            "start the game",
            "start the quiz",
            "play the quiz",
            "start a quiz"
          ]
        },
        {
          "name": "AMAZON.StopIntent",
          "samples": [

          ]
        }
      ],
      "types": {
        "name": "US_STATE_ABBR",
        "values": [
          {
            "name": {
              "value": "AK"
            }
          },
          {
            "name": {
              "value": "AL"
            }
          },
          {
            "name": {
              "value": "AZ"
            }
          }
        ]
      }
    }
  }
}
</pre>

## Resources

* alexa_modelbuilder https://rubygems.org/gems/alexa_modelbuilder

alex model json builder
