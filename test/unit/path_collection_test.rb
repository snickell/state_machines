require 'test_helper'

class PathCollectionByDefaultTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked

    @object = @klass.new
    @object.state = 'parked'

    @paths = StateMachines::PathCollection.new(@object, @machine)
  end

  def test_should_have_an_object
    assert_equal @object, @paths.object
  end

  def test_should_have_a_machine
    assert_equal @machine, @paths.machine
  end

  def test_should_have_a_from_name
    assert_equal :parked, @paths.from_name
  end

  def test_should_not_have_a_to_name
    assert_nil @paths.to_name
  end

  def test_should_have_no_from_states
    assert_equal [], @paths.from_states
  end

  def test_should_have_no_to_states
    assert_equal [], @paths.to_states
  end

  def test_should_have_no_events
    assert_equal [], @paths.events
  end

  def test_should_have_no_paths
    assert @paths.empty?
  end
end

class PathCollectionTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @object = @klass.new
  end

  def test_should_raise_exception_if_invalid_option_specified
    exception = assert_raises(ArgumentError) { StateMachines::PathCollection.new(@object, @machine, invalid: true) }
    assert_equal 'Unknown key: :invalid. Valid keys are: :from, :to, :deep, :guard', exception.message
  end

  def test_should_raise_exception_if_invalid_from_state_specified
    exception = assert_raises(IndexError) { StateMachines::PathCollection.new(@object, @machine, from: :invalid) }
    assert_equal ':invalid is an invalid name', exception.message
  end

  def test_should_raise_exception_if_invalid_to_state_specified
    exception = assert_raises(IndexError) { StateMachines::PathCollection.new(@object, @machine, to: :invalid) }
    assert_equal ':invalid is an invalid name', exception.message
  end
end

class PathCollectionWithPathsTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked, :idling, :first_gear
    @machine.event :ignite do
      transition parked: :idling
    end
    @machine.event :shift_up do
      transition idling: :first_gear
    end

    @object = @klass.new
    @object.state = 'parked'

    @paths = StateMachines::PathCollection.new(@object, @machine)
  end

  def test_should_enumerate_paths
    assert_equal [[
      StateMachines::Transition.new(@object, @machine, :ignite, :parked, :idling),
      StateMachines::Transition.new(@object, @machine, :shift_up, :idling, :first_gear)
    ]], @paths
  end

  def test_should_have_a_from_name
    assert_equal :parked, @paths.from_name
  end

  def test_should_not_have_a_to_name
    assert_nil @paths.to_name
  end

  def test_should_have_from_states
    assert_equal [:parked, :idling], @paths.from_states
  end

  def test_should_have_to_states
    assert_equal [:idling, :first_gear], @paths.to_states
  end

  def test_should_have_no_events
    assert_equal [:ignite, :shift_up], @paths.events
  end
end

class PathWithGuardedPathsTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked, :idling, :first_gear
    @machine.event :ignite do
      transition parked: :idling, if: lambda { false }
    end

    @object = @klass.new
    @object.state = 'parked'
  end

  def test_should_not_enumerate_paths_if_guard_enabled
    assert_equal [], StateMachines::PathCollection.new(@object, @machine)
  end

  def test_should_enumerate_paths_if_guard_disabled
    paths = StateMachines::PathCollection.new(@object, @machine, guard: false)
    assert_equal [[
      StateMachines::Transition.new(@object, @machine, :ignite, :parked, :idling)
    ]], paths
  end
end

class PathCollectionWithDuplicateNodesTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :shift_up do
      transition parked: :idling, idling: :first_gear
    end
    @machine.event :park do
      transition first_gear: :idling
    end
    @object = @klass.new
    @object.state = 'parked'

    @paths = StateMachines::PathCollection.new(@object, @machine)
  end

  def test_should_not_include_duplicates_in_from_states
    assert_equal [:parked, :idling, :first_gear], @paths.from_states
  end

  def test_should_not_include_duplicates_in_to_states
    assert_equal [:idling, :first_gear], @paths.to_states
  end

  def test_should_not_include_duplicates_in_events
    assert_equal [:shift_up, :park], @paths.events
  end
end

class PathCollectionWithFromStateTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked, :idling, :first_gear
    @machine.event :park do
      transition idling: :parked
    end

    @object = @klass.new
    @object.state = 'parked'

    @paths = StateMachines::PathCollection.new(@object, @machine, from: :idling)
  end

  def test_should_generate_paths_from_custom_from_state
    assert_equal [[
      StateMachines::Transition.new(@object, @machine, :park, :idling, :parked)
    ]], @paths
  end

  def test_should_have_a_from_name
    assert_equal :idling, @paths.from_name
  end
end

class PathCollectionWithToStateTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite do
      transition parked: :idling
    end
    @machine.event :shift_up do
      transition parked: :idling, idling: :first_gear
    end
    @machine.event :shift_down do
      transition first_gear: :idling
    end
    @object = @klass.new
    @object.state = 'parked'

    @paths = StateMachines::PathCollection.new(@object, @machine, to: :idling)
  end

  def test_should_stop_paths_once_target_state_reached
    assert_equal [
      [StateMachines::Transition.new(@object, @machine, :ignite, :parked, :idling)],
      [StateMachines::Transition.new(@object, @machine, :shift_up, :parked, :idling)]
    ], @paths
  end
end

class PathCollectionWithDeepPathsTest < MiniTest::Test
  def setup
    @klass = Class.new
    @machine = StateMachines::Machine.new(@klass)
    @machine.state :parked, :idling
    @machine.event :ignite do
      transition parked: :idling
    end
    @machine.event :shift_up do
      transition parked: :idling, idling: :first_gear
    end
    @machine.event :shift_down do
      transition first_gear: :idling
    end
    @object = @klass.new
    @object.state = 'parked'

    @paths = StateMachines::PathCollection.new(@object, @machine, to: :idling, deep: true)
  end

  def test_should_allow_target_to_be_reached_more_than_once_per_path
    assert_equal [
      [
        StateMachines::Transition.new(@object, @machine, :ignite, :parked, :idling)
      ],
      [
        StateMachines::Transition.new(@object, @machine, :ignite, :parked, :idling),
        StateMachines::Transition.new(@object, @machine, :shift_up, :idling, :first_gear),
        StateMachines::Transition.new(@object, @machine, :shift_down, :first_gear, :idling)
      ],
      [
        StateMachines::Transition.new(@object, @machine, :shift_up, :parked, :idling)
      ],
      [
        StateMachines::Transition.new(@object, @machine, :shift_up, :parked, :idling),
        StateMachines::Transition.new(@object, @machine, :shift_up, :idling, :first_gear),
        StateMachines::Transition.new(@object, @machine, :shift_down, :first_gear, :idling)
      ]
    ], @paths
  end
end
