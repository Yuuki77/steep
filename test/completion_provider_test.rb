require_relative "test_helper"

class CompletionProviderTest < Minitest::Test
  CompletionProvider = Steep::Project::CompletionProvider

  include FactoryHelper
  include SubtypingHelper

  def test_on_lower_identifier
    with_checker <<EOF do
extension Object (Pathname)
  def Pathname: () -> void
end
EOF
      CompletionProvider.new(source_text: <<-EOR, path: Pathname("foo.rb"), subtyping: checker).tap do |provider|
req

lvar1 = 1
lvar2 = "2"
lva
lvar1
      EOR

        provider.run(line: 1, column: 3).tap do |items|
          assert_equal [:require], items.map(&:identifier)
        end

        provider.run(line: 5, column: 3).tap do |items|
          assert_equal [:lvar1, :lvar2], items.map(&:identifier)
        end

        provider.run(line: 6, column: 5).tap do |items|
          assert_equal [:lvar1], items.map(&:identifier)
        end
      end
    end
  end

  def test_on_method_identifier
    with_checker do
      CompletionProvider.new(source_text: <<-EOR, path: Pathname("foo.rb"), subtyping: checker).tap do |provider|
self.cl
      EOR

        provider.run(line: 1, column: 7).tap do |items|
          assert_equal [:class], items.map(&:identifier)
        end

        provider.run(line: 1, column: 5).tap do |items|
          assert_equal [:class, :initialize, :itself, :nil?, :tap, :to_s], items.map(&:identifier).sort
        end
      end
    end
  end

  def test_on_ivar_identifier
    with_checker <<EOF do
class Hello
  @foo1: String
  @foo2: Integer

  def world: () -> void
end
EOF
      CompletionProvider.new(source_text: <<-EOR, path: Pathname("foo.rb"), subtyping: checker).tap do |provider|
class Hello
  def world
    @foo
    @foo2
  end
end
      EOR

        provider.run(line: 3, column: 8).tap do |items|
          assert_equal [:@foo1, :@foo2], items.map(&:identifier)
        end

        provider.run(line: 4, column: 9).tap do |items|
          assert_equal [:@foo2], items.map(&:identifier)
        end
      end
    end
  end

  def test_dot_trigger
    with_checker do
      CompletionProvider.new(source_text: <<-EOR, path: Pathname("foo.rb"), subtyping: checker).tap do |provider|
" ".
      EOR

        provider.run(line: 1, column: 4).tap do |items|
          assert_equal [:class, :initialize, :itself, :nil?, :size, :tap, :to_s, :to_str],
                       items.map(&:identifier).sort
        end
      end
    end
  end

  def test_on_atmark
    with_checker <<EOF do
class Hello
  @foo1: String
  @foo2: Integer

  def world: () -> void
end
EOF
      CompletionProvider.new(source_text: <<-EOR, path: Pathname("foo.rb"), subtyping: checker).tap do |provider|
class Hello
  def world
    @
  end
end
      EOR

        provider.run(line: 3, column: 5).tap do |items|
          assert_equal [:@foo1, :@foo2], items.map(&:identifier).sort
        end
      end
    end
  end

  def test_on_trigger
    with_checker <<EOF do
class Hello
  @foo1: String
  @foo2: Integer

  def world: () -> void
end
EOF
      CompletionProvider.new(source_text: <<-EOR, path: Pathname("foo.rb"), subtyping: checker).tap do |provider|
class Hello
  def world

  end

end
      EOR

        provider.run(line: 3, column: 0).tap do |items|
          assert_equal [:@foo1, :@foo2, :class, :gets, :initialize, :itself, :nil?, :puts, :require, :tap, :to_s, :world],
                       items.map(&:identifier).sort
        end

        provider.run(line: 5, column: 0).tap do |items|
          assert_equal [:attr_reader, :block_given?, :class, :gets, :initialize, :itself, :new, :nil?, :puts, :require, :tap, :to_s],
                       items.map(&:identifier).sort
        end
      end
    end
  end
end
