require_relative "test_helper"

class LangserverTest < Minitest::Test
  include TestHelper
  include ShellHelper

  def dirs
    @dirs ||= []
  end

  def langserver_command(steepfile=nil)
    "#{__dir__}/../exe/steep langserver --log-level=error".tap do |s|
      if steepfile
        s << " --steepfile=#{steepfile}"
      end
    end
  end

  def test_initialize
    in_tmpdir do
      (current_dir + "Steepfile").write <<EOF
target :app do end
EOF

      Open3.popen2(langserver_command(current_dir + "Steepfile")) do |stdin, stdout|
        reader = LanguageServer::Protocol::Transport::Io::Reader.new(stdout)
        writer = LanguageServer::Protocol::Transport::Io::Writer.new(stdin)

        lsp = LSPDouble.new(reader: reader, writer: writer)

        lsp.start do
          lsp.send_request(method: "initialize") do |response|
            assert_equal(
              {
                id: response[:id],
                result: {
                  capabilities: {
                    textDocumentSync: { change: 1 },
                    hoverProvider: true,
                  }
                },
                jsonrpc: "2.0"
              },
              response
            )
          end
        end
      end
    end
  end

  def test_did_change
    in_tmpdir do
      path = current_dir.realpath

      (path + "Steepfile").write <<EOF
target :app do
  check "workdir/example.rb"
end
EOF
      (path+"workdir").mkdir
      (path+"workdir/example.rb").write ""

      Open3.popen2(langserver_command(path + "Steepfile")) do |stdin, stdout|
        reader = LanguageServer::Protocol::Transport::Io::Reader.new(stdout)
        writer = LanguageServer::Protocol::Transport::Io::Writer.new(stdin)

        lsp = LSPDouble.new(reader: reader, writer: writer)

        lsp.start do
          lsp.send_request(method: "initialize") do |response|
            assert_equal(
              {
                id: response[:id],
                result: {
                  capabilities: {
                    textDocumentSync: { change: 1 },
                    hoverProvider: true,
                  }
                },
                jsonrpc: "2.0"
              },
              response
            )
          end

          finally_holds timeout: 30 do
            lsp.synchronize_ui do
              assert_equal [], lsp.diagnostics["file://#{path}/workdir/example.rb"]
            end
          end

          lsp.send_request(
            method: "textDocument/didChange",
            params: {
              textDocument: {
                uri: "file://#{path}/workdir/example.rb",
                version: 2,
              },
              contentChanges: [{text: "1.map()" }]
            }
          )

          assert_finally do
            lsp.synchronize_ui do
              lsp.diagnostics["file://#{path}/workdir/example.rb"].any? {|error|
                error[:message] == "workdir/example.rb:1:0: NoMethodError: type=::Integer, method=map"
              }
            end
          end

          lsp.send_request(
            method: "textDocument/didChange",
            params: {
              textDocument: {
                uri: "file://#{path}/workdir/example.rb",
                version: 3,
              },
              contentChanges: [{text: "1.to_s" }]
            }
          )

          finally_holds do
            lsp.synchronize_ui do
              assert_equal [], lsp.diagnostics["file://#{path}/workdir/example.rb"]
            end
          end

          lsp.send_request(
            method: "textDocument/didChange",
            params: {
              textDocument: {
                uri: "file://#{path}/workdir/example.rb",
                version: 4,
              },
              contentChanges: [{text: <<SRC }]
def foo
  # @type var string:
end
SRC
            }
          )

          assert_finally do
            lsp.synchronize_ui do
              lsp.diagnostics["file://#{path}/workdir/example.rb"].any? {|error|
                error[:message].start_with?("Syntax error on annotation: `@type var string:`,")
              }
            end
          end
        end
      end
    end
  end

  def test_hover
    in_tmpdir do
      path = current_dir.realpath

      (path + "Steepfile").write <<EOF
target :app do
  check "lib"
  signature "sig"
end
EOF

      (path+"sig").mkdir
      (path+"sig/example.rbs").write <<RBS
class Hello
  def foo: (Integer x) -> String
end
RBS
      (path+"lib").mkdir
      (path+"lib/example.rb").write <<RB
class Hello
  def foo(x)
    (x + 1).to_s
  end
end
RB

      Open3.popen2(langserver_command(path + "Steepfile")) do |stdin, stdout|
        reader = LanguageServer::Protocol::Transport::Io::Reader.new(stdout)
        writer = LanguageServer::Protocol::Transport::Io::Writer.new(stdin)

        lsp = LSPDouble.new(reader: reader, writer: writer)

        lsp.start do
          lsp.send_request(method: "initialize") do |response|
            assert_equal(
              {
                id: response[:id],
                result: {
                  capabilities: {
                    textDocumentSync: { change: 1 },
                    hoverProvider: true,
                  }
                },
                jsonrpc: "2.0"
              },
              response
            )
          end

          finally_holds timeout: 30 do
            lsp.synchronize_ui do
              assert_equal [], lsp.diagnostics["file://#{path}/lib/example.rb"]
              assert_equal [], lsp.diagnostics["file://#{path}/sig/example.rbs"]
            end
          end

          lsp.send_request(
            method: "textDocument/hover",
            params: {
              textDocument: {
                uri: "file://#{path}/lib/example.rb"
              },
              position: {
                line: 2,
                character: 5
              }
            }
          ) do |response|
            assert_equal "`x`: `::Integer`", response[:result][:contents][:value]
            assert_equal({ start: { line: 2, character: 5 }, end: { line: 2, character: 6 }}, response[:result][:range])
          end

          lsp.send_request(
            method: "textDocument/hover",
            params: {
              textDocument: {
                uri: "file://#{path}/lib/example.rb"
              },
              position: {
                line: 2,
                character: 9
              }
            }
          ) do |response|
            assert_equal "`::Integer`", response[:result][:contents][:value]
            assert_equal({ start: { line: 2, character: 9 }, end: { line: 2, character: 10 }}, response[:result][:range])
          end

          lsp.send_request(
            method: "textDocument/hover",
            params: {
              textDocument: {
                uri: "file://#{path}/lib/example.rb"
              },
              position: {
                line: 2,
                character: 12
              }
            }
          ) do |response|
            assert_equal "::Integer#to_s: `::String`", response[:result][:contents][:value]
            assert_equal({ start: { line: 2, character: 4 }, end: { line: 2, character: 16 }}, response[:result][:range])
          end
        end
      end
    end
  end
end
