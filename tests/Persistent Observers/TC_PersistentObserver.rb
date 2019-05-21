require 'testup/testcase'
require_relative '../../persistent_notifier.rb'

class TC_PersistentObserver < TestUp::TestCase
  def setup
    start_with_empty_model
  end

  def teardown
    discard_model_changes
  end

  class SelectionObserver < Sketchup::SelectionObserver
    attr_accessor :call_count

    def initialize
      @call_count = 0
    end

    def onSelectionAdded(_selection, entity)
      puts "onSelectionAdded: #{entity}"
      @call_count += 1
    end

    def onSelectionCleared(_selection)
      puts "onSelectionCleared"
      @call_count += 1
    end

    def onSelectionBulkChange(_selection)
      puts "onSelectionBulkChange"
      @call_count += 1
    end

    def onSelectionRemoved(_selection, entity)
      puts "onSelectionRemoved: #{entity}"
      @call_count += 1
    end

    # HACK: SU calls the wrong method.
    def onSelectedRemoved(*args)
      onSelectionRemoved(*args)
    end
  end

  # Sketchup::FrameChangeObserver is an abstract class and cannot be inherited from.
  # Hence this wrapper cannot identify what subject it is supposed to observer.
  class FrameChangeObserver; end

  # EntitiesObserver unsupported as this wrapper don't know what Entities object
  # to observer. Might in the future be all, the active one or the top one.
  class EntitiesObserver < Sketchup::EntitiesObserver; end

  def test_PersistentObserver
    observer = SelectionObserver.new
    PersistentNotifier.add_observer(observer)

    # Confirm start value.
    assert_equal(0, observer.call_count)

    # Confirm observer is attached and callback fires.
    change_selection
    assert_equal(1, observer.call_count)

    # Confirm observer can be removed.
    PersistentNotifier.remove_observer(observer)
    change_selection
    assert_equal(1, observer.call_count)

    # Confirm trying to remove more than once raises error.
    # REVIEW: Should it? Why?
    assert_raises(ArgumentError) do
      PersistentNotifier.remove_observer(observer)
    end

    # Confirm adding observer multiple times doesn't cause callback to fires
    # multiple times.
    observer.call_count = 0
    PersistentNotifier.add_observer(observer)
    PersistentNotifier.add_observer(observer)
    change_selection
    assert_equal(1, observer.call_count)

    # Confirm observer persist between models.
    open_new_model
    observer.call_count = 0
    change_selection
    assert_equal(1, observer.call_count)

    # Confirm exception for unsupported classes.
    assert_raises(ArgumentError) do
      PersistentNotifier.add_observer(FrameChangeObserver.new)
    end
    assert_raises(ArgumentError) do
      PersistentNotifier.add_observer(EntitiesObserver.new)
    end

    # Clean up.
    PersistentNotifier.remove_observer(observer)
  end

  private

  def change_selection
    model = Sketchup.active_model
    model.selection.add(model.entities.add_cpoint(ORIGIN))
  end
end
