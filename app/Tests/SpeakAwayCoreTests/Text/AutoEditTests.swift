import XCTest
@testable import SpeakAwayCore

final class AutoEditTests: XCTestCase {
    private func en(_ s: String) -> String { AutoEdit.clean(s, language: "en") }
    private func es(_ s: String) -> String { AutoEdit.clean(s, language: "es") }

    // MARK: fillers, English

    func testRemovesUmAndUhEnglish() {
        XCTAssertEqual(en("So um I think we should go"), "So I think we should go")
        XCTAssertEqual(en("I uh need a coffee."), "I need a coffee.")
        XCTAssertEqual(en("Um, I think so."), "I think so.")
        XCTAssertEqual(en("Well, uh, that works."), "Well, that works.")
        XCTAssertEqual(en("It was fine, um."), "It was fine.")
        XCTAssertEqual(en("Okay. Um, let's start."), "Okay. Let's start.")
        XCTAssertEqual(en("Hmm, erm, I am not sure."), "Hmm, I am not sure.")
    }

    func testKeepsHyphenatedAndRealWords() {
        XCTAssertEqual(en("She said uh-huh and left."), "She said uh-huh and left.")
        XCTAssertEqual(en("The umbrella is humming."), "The umbrella is humming.")
        XCTAssertEqual(en("An uhm of a problem"), "An of a problem")
    }

    func testYouKnowOnlyWhenIsolatedByCommas() {
        XCTAssertEqual(en("It was, you know, really great."), "It was, really great.")
        XCTAssertEqual(en("We went home, you know."), "We went home.")
        XCTAssertEqual(en("Do you know the way?"), "Do you know the way?")
        XCTAssertEqual(en("You know I love you."), "You know I love you.")
        XCTAssertEqual(en("I think you know what I mean."), "I think you know what I mean.")
    }

    // MARK: fillers, Spanish

    func testRemovesEhAndEhmSpanish() {
        XCTAssertEqual(es("Quiero, eh, un café"), "Quiero, un café")
        XCTAssertEqual(es("Ehm, hola a todos."), "Hola a todos.")
        XCTAssertEqual(es("Necesito eh la cotización."), "Necesito la cotización.")
        XCTAssertEqual(es("Mmm, déjame pensar."), "Déjame pensar.")
    }

    func testKeepsEhAsAQuestionTag() {
        XCTAssertEqual(es("Vamos mañana, ¿eh?"), "Vamos mañana, ¿eh?")
    }

    func testEsteOnlyWhenIsolatedByCommas() {
        XCTAssertEqual(es("Fue, este, muy bueno."), "Fue, muy bueno.")
        XCTAssertEqual(es("Prefiero este, no aquel."), "Prefiero este, no aquel.")
        XCTAssertEqual(es("Este libro es bueno."), "Este libro es bueno.")
        XCTAssertEqual(es("Quiero este modelo."), "Quiero este modelo.")
    }

    func testSpanishFillersAreNotTouchedInEnglish() {
        XCTAssertEqual(en("Eh, that is fine."), "Eh, that is fine.")
    }

    func testEnglishFillersAreNotTouchedInSpanish() {
        XCTAssertEqual(es("Uh, qué mal."), "Uh, qué mal.")
    }

    // MARK: stutters

    func testCollapsesStutterRepeats() {
        XCTAssertEqual(en("I think the the plan works"), "I think the plan works")
        XCTAssertEqual(en("I I think so."), "I think so.")
        XCTAssertEqual(en("We we we should go."), "We should go.")
        XCTAssertEqual(en("I-I think so."), "I think so.")
        XCTAssertEqual(es("Yo creo que que vamos bien"), "Yo creo que vamos bien")
        XCTAssertEqual(es("Voy a a la tienda."), "Voy a la tienda.")
        XCTAssertEqual(es("El el carro es rojo."), "El carro es rojo.")
    }

    func testKeepsLegitimateRepeats() {
        XCTAssertEqual(en("He said that that was fine."), "He said that that was fine.")
        XCTAssertEqual(en("It had had a problem."), "It had had a problem.")
        XCTAssertEqual(en("That is very very good."), "That is very very good.")
        XCTAssertEqual(en("No no no, stop."), "No no no, stop.")
        XCTAssertEqual(es("¿Qué qué dijiste?"), "¿Qué qué dijiste?")
        XCTAssertEqual(es("Poco a poco, sí sí."), "Poco a poco, sí sí.")
    }

    // MARK: backtracking, English

    func testBacktrackingTimeEnglish() {
        XCTAssertEqual(en("Let's meet at 2, actually 3."), "Let's meet at 3.")
        XCTAssertEqual(en("Let's meet at 2 pm, actually 3 pm."), "Let's meet at 3 pm.")
        XCTAssertEqual(en("Let's meet at 2, actually at 3."), "Let's meet at 3.")
        XCTAssertEqual(en("Call me at two, I mean three."), "Call me at three.")
        XCTAssertEqual(en("The meeting is at 2, wait, 4."), "The meeting is at 4.")
    }

    func testBacktrackingDaysAndNamesEnglish() {
        XCTAssertEqual(en("See you on Tuesday, I mean Wednesday."), "See you on Wednesday.")
        XCTAssertEqual(en("Send it to John, I mean Mike."), "Send it to Mike.")
        XCTAssertEqual(en("Send it to John Smith, actually Mike Jones."), "Send it to Mike Jones.")
        XCTAssertEqual(en("It is on March 3, actually March 5."), "It is on March 5.")
        XCTAssertEqual(en("Meet the manager, sorry, the director."), "Meet the director.")
    }

    func testBacktrackingKeepsTheRestOfTheSentence() {
        XCTAssertEqual(en("Let's meet at 2, actually 3, and then have lunch."), "Let's meet at 3, and then have lunch.")
        XCTAssertEqual(en("Hi. We meet at 2, actually 3. Bye."), "Hi. We meet at 3. Bye.")
    }

    func testBacktrackingIgnoresOrdinaryUsesOfTheMarker() {
        XCTAssertEqual(en("It was good, actually, very good."), "It was good, actually, very good.")
        XCTAssertEqual(en("I'm late, sorry, traffic was bad."), "I'm late, sorry, traffic was bad.")
        XCTAssertEqual(en("I said yes, no, I can't."), "I said yes, no, I can't.")
        XCTAssertEqual(en("I like it, I mean it."), "I like it, I mean it.")
        XCTAssertEqual(en("Thanks, sorry."), "Thanks, sorry.")
        XCTAssertEqual(en("I'd go at 2, rather than later."), "I'd go at 2, rather than later.")
    }

    // MARK: backtracking, Spanish

    func testBacktrackingSpanish() {
        XCTAssertEqual(es("Nos vemos a las 2, no, mejor a las 3."), "Nos vemos a las 3.")
        XCTAssertEqual(es("Nos vemos el martes, perdón, el miércoles."), "Nos vemos el miércoles.")
        XCTAssertEqual(es("El martes, perdón, el miércoles."), "El miércoles.")
        XCTAssertEqual(es("Llámame a las dos, digo, a las tres."), "Llámame a las tres.")
        XCTAssertEqual(es("Se lo mando a Juan, mejor dicho, a Pedro."), "Se lo mando a Pedro.")
        XCTAssertEqual(es("Es el lunes, perdón, el viernes por la tarde."), "Es el viernes por la tarde.")
        XCTAssertEqual(es("Nos vemos a las 2, no, a las 3."), "Nos vemos a las 3.")
    }

    func testBacktrackingSpanishIgnoresOrdinaryUses() {
        XCTAssertEqual(es("Dijo que no, no vino nadie."), "Dijo que no, no vino nadie.")
        XCTAssertEqual(es("Llegué tarde, perdón, había tráfico."), "Llegué tarde, perdón, había tráfico.")
        XCTAssertEqual(es("No, gracias."), "No, gracias.")
    }

    func testBacktrackingNeedsLanguageMatch() {
        XCTAssertEqual(en("Nos vemos el martes, perdón, el miércoles."), "Nos vemos el martes, perdón, el miércoles.")
    }

    // MARK: spacing and capitalization

    func testFixesSpacingAroundPunctuation() {
        XCTAssertEqual(en("Hello  world , how are you ?"), "Hello world, how are you?")
        XCTAssertEqual(en("hello,world"), "Hello, world")
        XCTAssertEqual(es("¿ Cómo estás ?"), "¿Cómo estás?")
    }

    func testCapitalizesSentenceStarts() {
        XCTAssertEqual(en("hello there. how are you? fine! thanks"), "Hello there. How are you? Fine! Thanks")
        XCTAssertEqual(es("hola a todos. ¿cómo están? bien"), "Hola a todos. ¿Cómo están? Bien")
        XCTAssertEqual(es("¡qué bueno! nos vemos"), "¡Qué bueno! Nos vemos")
    }

    func testCapitalizationIsConservative() {
        XCTAssertEqual(en("iPhone is great. see you"), "iPhone is great. See you")
        XCTAssertEqual(en("e.g. the cat and etc. the dog"), "e.g. the cat and etc. the dog")
        XCTAssertEqual(en("visit example.com. then relax"), "Visit example.com. Then relax")
        XCTAssertEqual(en("wait... and then we left"), "Wait... and then we left")
        XCTAssertEqual(en("it costs 3.5 dollars"), "It costs 3.5 dollars")
        XCTAssertEqual(es("llegó el dr. pérez ayer"), "Llegó el dr. pérez ayer")
    }

    // MARK: whole behaviour

    func testKeepsOuterWhitespace() {
        XCTAssertEqual(en("um hello there. "), "Hello there. ")
        XCTAssertEqual(en("  hello"), "  Hello")
    }

    func testEmptyAndFillerOnlyText() {
        XCTAssertEqual(en(""), "")
        XCTAssertEqual(en("   "), "   ")
        XCTAssertEqual(en("Um."), "")
        XCTAssertEqual(es("Mmm"), "")
    }

    func testNilLanguageAppliesBothSets() {
        XCTAssertEqual(AutoEdit.clean("Quiero, eh, un café", language: nil), "Quiero, un café")
        XCTAssertEqual(AutoEdit.clean("So um we go", language: nil), "So we go")
        XCTAssertEqual(AutoEdit.clean("Let's meet at 2, actually 3.", language: nil), "Let's meet at 3.")
    }

    func testRegionalLanguageCodes() {
        XCTAssertEqual(AutoEdit.clean("Quiero, eh, un café", language: "es-PA"), "Quiero, un café")
        XCTAssertEqual(AutoEdit.clean("So um we go", language: "en-US"), "So we go")
    }

    func testUnknownLanguageOnlyTidiesSpacing() {
        XCTAssertEqual(AutoEdit.clean("Um , bonjour  tout le monde", language: "fr"), "Um, bonjour tout le monde")
    }

    func testRealSentencesWithSeveralEdits() {
        XCTAssertEqual(
            en("um so I I wanted to uh ask if we can meet at 2, actually 3, on Tuesday"),
            "So I wanted to ask if we can meet at 3, on Tuesday")
        XCTAssertEqual(
            es("eh hola Carla, te te mando la cotización el martes, perdón, el miércoles"),
            "Hola Carla, te mando la cotización el miércoles")
    }
}
