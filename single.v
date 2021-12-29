module rxv

import context

// Single is an observable with a single element
pub interface Single {
	Iterable
mut:
	filter(apply Predicate, opts ...RxOption) OptionalSingle
	get(opts ...RxOption) ?Item
	map(apply Func, opts ...RxOption) Single
	run(opts ...RxOption) chan int
}

// SingleImpl implements Single
pub struct SingleImpl {
mut:
	iterable Iterable
	parent   context.Context
}

// observe observes an OptionalSingle by returning its channel.
fn (mut o SingleImpl) observe(opts ...RxOption) chan Item {
	return o.iterable.observe(...opts)
}

// get returns the item. The error returned is if the context has been cancelled.
// This method is blocking.
pub fn (mut o SingleImpl) get(opts ...RxOption) ?Item {
	option := parse_options(...opts)
	mut ctx := option.build_context(o.parent)

	observe := o.observe(...opts)
	done := ctx.done()

	for {
		select {
			_ := <-done {
				err := ctx.err()
				if err is none {
					return Item{}
				}
				return err
			}
			v := <-observe {
				return v
			}
		}
	}
	return optional_single_empty
}

struct FilterOperatorSingle {
	apply Predicate
}

fn (op &FilterOperatorSingle) next(mut ctx context.Context, item Item, dst chan Item, operator_options OperatorOptions) {
	if op.apply(item.value) {
		item.send_context(mut &ctx, dst)
	}
}

fn (op &FilterOperatorSingle) err(mut ctx context.Context, item Item, dst chan Item, operator_options OperatorOptions) {
	default_error_func_operator(mut &ctx, item, dst, operator_options)
}

fn (op &FilterOperatorSingle) end(mut _ context.Context, _ chan Item) {}

fn (op &FilterOperatorSingle) gather_next(mut _ context.Context, item Item, dst chan Item, _ OperatorOptions) {}

// filter amits only those items from an Observable that pass a predicate test
// pub fn (mut s SingleImpl) filter(apply Predicate, opts ...RxOption) OptionalSingle {
// 	return optional_single(s.parent, mut s, fn () Operator {
// 		return &FilterOperatorSingle{
// 			apply: unsafe { voidptr(0) } // apply
// 		}
// 	}, true, true, ...opts)
// }

struct MapOperatorSingle {
	apply Func
}

fn (op &MapOperatorSingle) next(mut ctx context.Context, item Item, dst chan Item, operator_options OperatorOptions) {
	if res := op.apply(mut &ctx, item.value) {
		dst <- of(res)
	} else {
		dst <- from_error(err)
		operator_options.stop()
	}
}

fn (op &MapOperatorSingle) err(mut ctx context.Context, item Item, dst chan Item, operator_options OperatorOptions) {
	default_error_func_operator(mut &ctx, item, dst, operator_options)
}

fn (op &MapOperatorSingle) end(mut _ context.Context, _ chan Item) {}

fn (op &MapOperatorSingle) gather_next(mut _ context.Context, item Item, dst chan Item, _ OperatorOptions) {
	if item.value is MapOperatorSingle {
		return
	}
	dst <- item
}

// map transforms the items emitted by an optional_single by applying a function to each item
// pub fn (mut o SingleImpl) map(apply Func, opts ...RxOption) Single {
// 	return single(o.parent, mut o, fn () Operator {
// 		return &MapOperatorSingle{
// 			apply: unsafe { voidptr(0) } // apply
// 		}
// 	}, false, true, ...opts)
// }

// run creates an observer without consuming the emitted items
pub fn (mut o SingleImpl) run(opts ...RxOption) chan int {
	dispose := chan int{}
	option := parse_options(...opts)
	mut ctx := option.build_context(o.parent)

	observe := o.observe(...opts)

	go fn (dispose chan int, mut ctx context.Context, observe chan Item) {
		defer {
			dispose.close()
		}

		done := ctx.done()
		for {
			select {
				_ := <-done {
					return
				}
				_ := <-observe {}
			}
		}
	}(dispose, mut &ctx, observe)

	return dispose
}
