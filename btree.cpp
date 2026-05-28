/**
 * B-Tree Implementation in C++
 * CMPT 225 Final Project
 *
 * Implements a B-Tree of order t (minimum degree t):
 *   - Every non-root node has at least t-1 keys
 *   - Every node has at most 2t-1 keys
 *   - Supports: search, insert (with split), delete (with merge/borrow)
 *
 * 
 */

#include <iostream>
#include <vector>
#include <cassert>
#include <chrono>
#include <random>
#include <algorithm>
#include <iomanip>

// ─────────────────────────────────────────────
// BTreeNode
// ─────────────────────────────────────────────
struct BTreeNode {
    int t;                          // minimum degree
    std::vector<int> keys;
    std::vector<BTreeNode*> children;
    bool leaf;

    BTreeNode(int t, bool leaf) : t(t), leaf(leaf) {}

    ~BTreeNode() {
        for (auto* c : children) delete c;
    }

    // Search for key k; returns node and index, or {nullptr,-1}
    std::pair<BTreeNode*, int> search(int k) {
        int i = 0;
        while (i < (int)keys.size() && k > keys[i]) i++;
        if (i < (int)keys.size() && keys[i] == k)
            return {this, i};
        if (leaf)
            return {nullptr, -1};
        return children[i]->search(k);
    }

    // Split full child at index i
    void splitChild(int i, BTreeNode* y) {
        BTreeNode* z = new BTreeNode(t, y->leaf);
        // z gets the upper half of y's keys
        z->keys.assign(y->keys.begin() + t, y->keys.end());
        y->keys.resize(t - 1);
        // z gets the upper half of y's children (if non-leaf)
        if (!y->leaf) {
            z->children.assign(y->children.begin() + t, y->children.end());
            y->children.resize(t);
        }
        // Move median key up into this node
        keys.insert(keys.begin() + i, y->keys[t - 1]);
        y->keys.resize(t - 1);
        children.insert(children.begin() + i + 1, z);
    }

    // Insert into non-full node
    void insertNonFull(int k) {
        int i = (int)keys.size() - 1;
        if (leaf) {
            keys.push_back(0);
            while (i >= 0 && keys[i] > k) {
                keys[i + 1] = keys[i];
                i--;
            }
            keys[i + 1] = k;
        } else {
            while (i >= 0 && keys[i] > k) i--;
            i++;
            if ((int)children[i]->keys.size() == 2 * t - 1) {
                splitChild(i, children[i]);
                if (keys[i] < k) i++;
            }
            children[i]->insertNonFull(k);
        }
    }

    // Find index of first key >= k
    int findKey(int k) {
        int idx = 0;
        while (idx < (int)keys.size() && keys[idx] < k) idx++;
        return idx;
    }

    // Delete key k from subtree rooted here
    void remove(int k) {
        int idx = findKey(k);

        if (idx < (int)keys.size() && keys[idx] == k) {
            // Case 1/2: key is in this node
            if (leaf) {
                // Case 1: leaf — just remove
                keys.erase(keys.begin() + idx);
            } else {
                // Case 2: internal node
                if ((int)children[idx]->keys.size() >= t) {
                    // 2a: predecessor
                    int pred = getPred(idx);
                    keys[idx] = pred;
                    children[idx]->remove(pred);
                } else if ((int)children[idx + 1]->keys.size() >= t) {
                    // 2b: successor
                    int succ = getSucc(idx);
                    keys[idx] = succ;
                    children[idx + 1]->remove(succ);
                } else {
                    // 2c: merge
                    merge(idx);
                    children[idx]->remove(k);
                }
            }
        } else {
            // Case 3: key not in this node
            if (leaf) return; // key not in tree
            bool isLast = (idx == (int)keys.size());
            if ((int)children[idx]->keys.size() < t)
                fill(idx);
            if (isLast && idx > (int)keys.size())
                children[idx - 1]->remove(k);
            else
                children[idx]->remove(k);
        }
    }

    int getPred(int idx) {
        BTreeNode* cur = children[idx];
        while (!cur->leaf) cur = cur->children.back();
        return cur->keys.back();
    }

    int getSucc(int idx) {
        BTreeNode* cur = children[idx + 1];
        while (!cur->leaf) cur = cur->children.front();
        return cur->keys.front();
    }

    void merge(int idx) {
        BTreeNode* child = children[idx];
        BTreeNode* sibling = children[idx + 1];
        child->keys.push_back(keys[idx]);
        child->keys.insert(child->keys.end(), sibling->keys.begin(), sibling->keys.end());
        child->children.insert(child->children.end(), sibling->children.begin(), sibling->children.end());
        sibling->children.clear(); // prevent double-delete
        keys.erase(keys.begin() + idx);
        children.erase(children.begin() + idx + 1);
        delete sibling;
    }

    void fill(int idx) {
        if (idx != 0 && (int)children[idx - 1]->keys.size() >= t)
            borrowFromPrev(idx);
        else if (idx != (int)keys.size() && (int)children[idx + 1]->keys.size() >= t)
            borrowFromNext(idx);
        else {
            if (idx != (int)keys.size()) merge(idx);
            else merge(idx - 1);
        }
    }

    void borrowFromPrev(int idx) {
        BTreeNode* child = children[idx];
        BTreeNode* sibling = children[idx - 1];
        child->keys.insert(child->keys.begin(), keys[idx - 1]);
        if (!child->leaf)
            child->children.insert(child->children.begin(), sibling->children.back());
        keys[idx - 1] = sibling->keys.back();
        sibling->keys.pop_back();
        if (!sibling->leaf) sibling->children.pop_back();
    }

    void borrowFromNext(int idx) {
        BTreeNode* child = children[idx];
        BTreeNode* sibling = children[idx + 1];
        child->keys.push_back(keys[idx]);
        if (!child->leaf)
            child->children.push_back(sibling->children.front());
        keys[idx] = sibling->keys.front();
        sibling->keys.erase(sibling->keys.begin());
        if (!sibling->leaf) sibling->children.erase(sibling->children.begin());
    }

    // In-order traversal
    void traverse(std::vector<int>& out) const {
        int i;
        for (i = 0; i < (int)keys.size(); i++) {
            if (!leaf) children[i]->traverse(out);
            out.push_back(keys[i]);
        }
        if (!leaf) children[i]->traverse(out);
    }

    int height() const {
        if (leaf) return 0;
        return 1 + children[0]->height();
    }
};

// ─────────────────────────────────────────────
// b-Tree
// ──────────────
class BTree {
public:
    BTreeNode* root;
    int t; // minimum degree

    BTree(int t) : root(nullptr), t(t) {}

    ~BTree() { delete root; }

    bool search(int k) {
        if (!root) return false;
        auto [node, idx] = root->search(k);
        return node != nullptr;
    }

    void insert(int k) {
        if (!root) {
            root = new BTreeNode(t, true);
            root->keys.push_back(k);
            return;
        }
        if ((int)root->keys.size() == 2 * t - 1) {
            // Root is full — create new root and split
            BTreeNode* s = new BTreeNode(t, false);
            s->children.push_back(root);
            s->splitChild(0, root);
            int i = (s->keys[0] < k) ? 1 : 0;
            s->children[i]->insertNonFull(k);
            root = s;
        } else {
            root->insertNonFull(k);
        }
    }

    void remove(int k) {
        if (!root) return;
        root->remove(k);
        if (root->keys.empty()) {
            BTreeNode* old = root;
            root = root->leaf ? nullptr : root->children[0];
            old->children.clear();
            delete old;
        }
    }

    std::vector<int> inorder() const {
        std::vector<int> out;
        if (root) root->traverse(out);
        return out;
    }

    int height() const {
        return root ? root->height() : -1;
    }

    int size() const {
        auto v = inorder();
        return (int)v.size();
    }
};

// ───────────────────
// Correctness tests
// ──────────────
void runTests() {
    std::cout << "=== Correctness Tests ===\n";

    // Test 1: Sorted order maintained
    {
        BTree bt(3);
        std::vector<int> vals = {10, 20, 5, 6, 12, 30, 7, 17};
        for (int v : vals) bt.insert(v);
        auto sorted = bt.inorder();
        bool ok = std::is_sorted(sorted.begin(), sorted.end());
        std::cout << "[" << (ok ? "PASS" : "FAIL") << "] Sorted order after insertion\n";
    }

    // Test 2: Search
    {
        BTree bt(2);
        for (int i = 1; i <= 20; i++) bt.insert(i * 3);
        bool found = bt.search(15);
        bool notFound = !bt.search(16);
        std::cout << "[" << (found && notFound ? "PASS" : "FAIL") << "] Search correctness\n";
    }

    // Test 3: Delete leaf key
    {
        BTree bt(3);
        for (int i : {1, 2, 3, 4, 5, 6, 7}) bt.insert(i);
        bt.remove(4);
        bool ok = !bt.search(4) && bt.search(3) && bt.search(5);
        std::cout << "[" << (ok ? "PASS" : "FAIL") << "] Delete leaf key\n";
    }

    // Test 4: Delete internal key
    {
        BTree bt(2);
        for (int i = 1; i <= 15; i++) bt.insert(i);
        bt.remove(7);
        auto v = bt.inorder();
        bool ok = std::is_sorted(v.begin(), v.end()) && !bt.search(7);
        std::cout << "[" << (ok ? "PASS" : "FAIL") << "] Delete internal key\n";
    }

    // Test 5: Large insertion + sorted invariant
    {
        BTree bt(5);
        std::mt19937 rng(42);
        std::uniform_int_distribution<int> dist(1, 100000);
        std::vector<int> inserted;
        for (int i = 0; i < 1000; i++) {
            int v = dist(rng);
            bt.insert(v);
            inserted.push_back(v);
        }
        auto v = bt.inorder();
        // B-tree stores duplicates; check sorted order and count match
        std::sort(inserted.begin(), inserted.end());
        bool ok = std::is_sorted(v.begin(), v.end()) && (v.size() == inserted.size());
        std::cout << "[" << (ok ? "PASS" : "FAIL") << "] Large random insertion invariant\n";
    }

    std::cout << "\n";
}

// 
// Performanc
// ──────────────
void benchmark() {
    std::cout << "=== Performance Benchmarks ===\n";
    std::cout << std::left
              << std::setw(12) << "Order (t)"
              << std::setw(12) << "N"
              << std::setw(16) << "Insert (ms)"
              << std::setw(16) << "Search (ms)"
              << std::setw(10) << "Height"
              << "\n";
    std::cout << std::string(66, '-') << "\n";

    std::vector<int> orders = {2, 5, 10, 50, 100};
    std::vector<int> sizes = {10000, 50000, 100000};

    for (int t : orders) {
        for (int N : sizes) {
            std::mt19937 rng(123);
            std::uniform_int_distribution<int> dist(1, N * 10);
            std::vector<int> data(N);
            for (auto& d : data) d = dist(rng);

            BTree bt(t);

            // Insert
            auto t0 = std::chrono::high_resolution_clock::now();
            for (int v : data) bt.insert(v);
            auto t1 = std::chrono::high_resolution_clock::now();
            double ins_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();

            // Search
            auto t2 = std::chrono::high_resolution_clock::now();
            for (int v : data) bt.search(v);
            auto t3 = std::chrono::high_resolution_clock::now();
            double srch_ms = std::chrono::duration<double, std::milli>(t3 - t2).count();

            std::cout << std::left
                      << std::setw(12) << t
                      << std::setw(12) << N
                      << std::setw(16) << std::fixed << std::setprecision(2) << ins_ms
                      << std::setw(16) << srch_ms
                      << std::setw(10) << bt.height()
                      << "\n";
        }
    }
}

int main() {
    runTests();
    benchmark();
    return 0;
}
