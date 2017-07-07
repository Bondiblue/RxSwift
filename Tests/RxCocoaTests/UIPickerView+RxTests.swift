//
//  UIPickerView+RxTests.swift
//  Tests
//
//  Created by Segii Shulga on 5/12/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import RxSwift
import RxCocoa
import UIKit
import XCTest


final class UIPickerViewTests: RxTest {
    
    func testPickerView_DelegateEventCompletesOnDealloc() {
        let createView: () -> UIPickerView = { UIPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1)) }
        
        ensureEventDeallocated(createView) { (view: UIPickerView) in view.rx.itemSelected }
    }

    func testPickerView_itemSelected() {
        let pickerView = UIPickerView()
        let row = 0
        let component = 0
        var result: (row: Int, component: Int)?
        
        autoreleasepool {
            _ = pickerView.rx.itemSelected.subscribe(onNext: { (element) in
                result = element
            })
            pickerView.delegate!.pickerView!(pickerView,
                didSelectRow: row,
                inComponent: component)
        }
        XCTAssertEqual(result?.row, row)
        XCTAssertEqual(result?.component, component)
    }
    
    func testItUsesAdapterToDisplayItems() {
        var titleForRowCalled = false
        let items = Observable.just([[1, 2], [1, 2, 3]])
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        let adapter = StubPickerViewAdapter()
        
        adapter.titleForRow = { _ in
            titleForRowCalled = true
            return ""
        }
        
        _ = items.bind(to: pickerView.rx.items(adapter: adapter))
        
        XCTAssertTrue(titleForRowCalled)
    }
    
    func testAdapterIsBeingRetainedUntilPickerViewDealloc() {
        var adapterDeallocated = false
        
        autoreleasepool {
            let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            let items = Observable.just([[1, 2], [1, 2, 3]])
            let adapter = TestPickerViewAdapter()
            
            _ = items.bind(to: pickerView.rx.items(adapter: adapter))
            
            _ = adapter.rx.deallocated.subscribe(onNext: { _ in
                adapterDeallocated = true
            })
            
            XCTAssertFalse(adapterDeallocated)
        }
        
        XCTAssertTrue(adapterDeallocated)
    }
    
    func testAdapterIsBeingRetainedUntilDisposed() {
        var adapterDeallocated = false
        var outerPicker: UIPickerView?
        var adapterSubscription: Disposable!
        
        autoreleasepool {
            let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            let items = Observable.just([[1, 2], [1, 2, 3]])
            let adapter = TestPickerViewAdapter()
            
            outerPicker = pickerView
            adapterSubscription = items.bind(to: pickerView.rx.items(adapter: adapter))
            
            _ = adapter.rx.deallocated.subscribe(onNext: { _ in
                adapterDeallocated = true
            })
        }
        
        XCTAssertFalse(adapterDeallocated)
        autoreleasepool { adapterSubscription.dispose() }
        XCTAssertTrue(adapterDeallocated)
    }
    
    func testReceiveSelectionEventsAfterBindingAdapter() {
        var selectedItem: (Int, Int)!
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let items = Observable.just([[1, 2], [1, 2, 3]])
        let adapter = TestPickerViewAdapter()
        
        _ = pickerView.rx.itemSelected.subscribe(onNext: { item in
            selectedItem = item
        })
        
        _ = items.bind(to: pickerView.rx.items(adapter: adapter))
        
        pickerView.delegate!.pickerView!(pickerView, didSelectRow: 0, inComponent: 1)
        
        XCTAssertEqual(selectedItem.0, 0)
        XCTAssertEqual(selectedItem.1, 1)
    }
    
    func testDisplayItemsAfterItemSelectionSubscription() {
        var titleForRowCalled = false
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        let items = PublishSubject<[[Int]]>()
        let stubAdapter = StubPickerViewAdapter()
        
        stubAdapter.titleForRow = { _, _, _ in
            titleForRowCalled = true
            return ""
        }
        _ = items.bind(to: pickerView.rx.items(adapter: stubAdapter))
        _ = pickerView.rx.itemSelected.subscribe(onNext: { _ in
        })
        
        items.onNext([[1, 2], [1, 2, 3]])
        
        XCTAssertTrue(titleForRowCalled)
    }
}

final class StubPickerViewAdapter: TestPickerViewAdapter {
    var titleForRow: ((UIPickerView, Int, Int) -> String?)!
    
    override func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return titleForRow(pickerView, row, component)
    }
}

class TestPickerViewAdapter: NSObject, RxPickerViewDataSourceType, UIPickerViewDataSource, UIPickerViewDelegate {
    typealias Element = [[Int]]
    private var items: [[Int]] = []
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return items.count
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return items[component].count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(items[component][row])"
    }
    
    func pickerView(_ pickerView: UIPickerView, observedEvent: Event<Element>) {
        switch observedEvent {
        case .next(let items):
            self.items = items
            pickerView.reloadAllComponents()
            pickerView.setNeedsLayout()
            pickerView.layoutIfNeeded() //force layout in test
        default:
            break
        }
    }
}
