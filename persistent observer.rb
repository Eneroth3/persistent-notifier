# Wrapper for adding observers that persists between models.
#
# Used to avoid boilerplate code for re-adding observer to new models.
module PersistentNotifier
  # The observer classes supported by this wrapper.
  VALID_OBSERVERS = [
    Sketchup::ModelObserver,
    Sketchup::SelectionObserver,
    Sketchup::PagesObserver
  ].freeze

  # Registered observers and the subjects they are observing.
  # A single observer may observe multiple objects, e.g. multiple open models
  # on Mac.
  @observers ||= {}

  # TODO: At some point purge deleted subjects from @observers hash values.

  # Add observer and have it persists between models.
  #
  # @param observer [Object]
  #   See VALID_OBSERVERS for supported observer classes.
  #   What object observer gets attached to is determined by its class.
  #
  #   AppObservers and FrameChangeObservers are already persistent in SketchUp
  #   and not supported by this wrapper.
  #
  #   Observers listening to entities that can re-occur in a model, e.g.
  #   DrawingElements, are not supported, as this wrapper can't know what entity
  #   you want to listen to.
  def self.add_observer(observer)
    raise ArgumentError unless VALID_OBSERVERS.any? { |c| observer.is_a?(c) }

    @observers[observer] ||= Set.new

    # SketchUp doesn't offer a way to iterate open models, which could otherwise
    # be used to attach observers to them all. Instead listen to
    # AppObserver#onActivateModel to attach observer to any other model when
    # relevant.
    # OPIMIZE: Should there be a separate method attaching only this observer,
    # instead of iterating all observers and try to attach them?
    register_observers(Sketchup.active_model)

    nil
  end

  # Remove persistent observer.
  #
  # @param observer [Object]
  #   See VALID_OBSERVERS for supported observer classes.
  #
  # @raises [ArgumentError] if observer has not first been added.
  def self.remove_observer(observer)
    raise ArgumentError unless VALID_OBSERVERS.any? { |c| observer.is_a?(c) }
    raise ArgumentError, "Observer not attached." unless @observers[observer]

    @observers[observer].each { |s| s.remove_observer(observer) if valid?(s) }
    @observers.delete(observer)

    nil
  end

  #-----------------------------------------------------------------------------

  # Internal method for actually actually registering the observers to the
  # SketchUp Ruby API.
  #
  # @param model [Sketchup::Model]
  #
  # @return [void]
  def self.register_observers(model)
    @observers.each do |observer, subjects|
      subject = guess_subject(model, observer)
      # Don't add duplicates.
      next if subjects.include?(subject)
      subject.add_observer(observer)
      subjects.add(subject)
    end
  end
  private_class_method :register_observers

  # Get object to attach observer to based on observer's class.
  #
  # @param model [Sketchup::Model]
  # @param observer [Object]
  #
  # @return [#add_observer]
  def self.guess_subject(model, observer)
    case observer
    when Sketchup::ModelObserver
      model
    when Sketchup::SelectionObserver
      model.selection
    when Sketchup::PagesObserver
      model.pages
    else
      raise ArgumentError
    end
  end
  private_class_method :guess_subject

  # Check if object still exists.
  #
  # @param object [Sketchup::Entity, #model]
  def self.valid?(object)
    # There is no #valid? method for Selection. Instead check if its model
    # is valid.
    (object.is_a?(Sketchup::Entity) && object.valid?) \
    || (object.respond_to?(:model) && object.model.valid?)
  end

  # @private
  # Expected to be called whenever a model is created, opened, or activated
  # (switched to in multi document Mac version of SketchUp).
  def self.on_model_init(model)
    register_observers(model)
  end

  # @private
  class AppObserver < Sketchup::AppObserver
    def expectsStartupModelNotifications
      true
    end

    def onNewModel(model)
      PersistentNotifier.on_model_init(model)
    end

    def onOpenModel(model)
      PersistentNotifier.on_model_init(model)
    end

    def onActivateModel(model)
      PersistentNotifier.on_model_init(model)
    end
  end

  unless @loaded
    @loaded = true
    # OPTIMIZE: Attach when @observers gets first entry and remove when it is
    # emptied?
    Sketchup.add_observer(AppObserver.new)
  end
end
