; Spock Specification class
(class_definition
  name: (identifier) @namespace.name) @namespace.definition

; Spock feature method: def "should do something"() { ... }
(function_definition
  function: (quoted_identifier
    (string_content) @test.name)) @test.definition
