require_relative "../persistent_notifier.rb"

# Example of how PersistentNotifier can be used for inspecting the selection.
#
# If everything works, the window count should change whenever the selection
# changes, even after a new model has been opened.
#
# This is a simplified example; in a real use case the window content should
# update when the user switches model and probably display something more
# useful than the type names.
class SelectionInspector < Sketchup::SelectionObserver
  def show
    create_dialog unless @dialog
    update_dialog_content
    @dialog.show
    PersistentNotifier.add_observer(self)
  end

  def hide
    @dialog.close
  end

  def visible?
    @dialog && @dialog.visible?
  end

  def toggle
    visible? ? hide : show
  end

  def command_state
    visible? ? MF_CHECKED : MF_UNCHECKED
  end

  # @api
  # Called when user empties the selection.
  def onSelectionCleared(_selection)
    puts "onSelectionCleared was called here"
    update_dialog_content
  end

  # @api
  # Called when user picks something with Select tool.
  def onSelectionBulkChange(_selection)
    puts "onSelectionBulkChange was called here"
    update_dialog_content
  end

  private

  def create_dialog
    @dialog = UI::HtmlDialog.new(dialog_title: "Selection Inspector")
    @dialog.set_on_closed { PersistentNotifier.remove_observer(self) }
  end

  def update_dialog_content
    content = Sketchup.active_model.selection.map(&:typename).join("<br />")
    @dialog.set_html(content)
  end
end

unless @loaded
  @loaded = true
  selection_inspector ||= SelectionInspector.new
  command = UI::Command.new("Inspect Selection") { selection_inspector.toggle }
  command.set_validation_proc { selection_inspector.command_state }
  UI.menu("Plugins").add_item(command)
end
